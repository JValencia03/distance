package plans

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

// PostgresStore persists plans in PostgreSQL. The schema lives in
// internal/database/migrations.
type PostgresStore struct {
	pool *pgxpool.Pool
}

func NewPostgresStore(pool *pgxpool.Pool) *PostgresStore {
	return &PostgresStore{pool: pool}
}

// selectPlans reads plans with their participants' ids and zones, both in
// joining order. (plan_id, user_id) is unique, so both arrays use the same
// order.
const selectPlans = `
SELECT id, activity_id, title, description, zone_id, place, starts_at,
       duration_minutes, max_participants, creator_id, status,
       ARRAY(SELECT user_id FROM plan_participants pp
             WHERE pp.plan_id = plans.id
             ORDER BY joined_at, user_id) AS participant_ids,
       ARRAY(SELECT zone_id FROM plan_participants pp
             WHERE pp.plan_id = plans.id
             ORDER BY joined_at, user_id) AS participant_zones
FROM plans`

func (s *PostgresStore) Create(ctx context.Context, p Plan) error {
	return pgx.BeginFunc(ctx, s.pool, func(tx pgx.Tx) error {
		var description *string
		if p.Description != "" {
			description = &p.Description
		}
		var limit *int
		if p.MaxParticipants > 0 {
			limit = &p.MaxParticipants
		}
		_, err := tx.Exec(ctx, `
			INSERT INTO plans (id, activity_id, title, description, zone_id, place,
			                   starts_at, duration_minutes, max_participants, creator_id, status)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
			p.ID, p.Activity.ID, p.Title, description, p.Zone.ID, p.Place,
			p.StartsAt, int(p.Duration/time.Minute), limit, p.CreatorID, string(p.Status))
		if err != nil {
			return fmt.Errorf("insert plan: %w", err)
		}
		for _, pt := range p.Participants {
			if _, err := tx.Exec(ctx,
				"INSERT INTO plan_participants (plan_id, user_id, zone_id) VALUES ($1, $2, $3)",
				p.ID, pt.UserID, pt.Zone.ID); err != nil {
				return fmt.Errorf("insert participant: %w", err)
			}
		}
		return nil
	})
}

func (s *PostgresStore) Get(ctx context.Context, id string) (Plan, error) {
	return getPlan(ctx, s.pool, id)
}

// Current bounds starts_at by the longest possible duration, so the query can
// still use the starts_at index before checking each plan's own end.
func (s *PostgresStore) Current(ctx context.Context, now time.Time) ([]Plan, error) {
	rows, err := s.pool.Query(ctx, selectPlans+`
		WHERE status = 'active' AND starts_at > $2
		  AND starts_at + make_interval(mins => duration_minutes) > $1
		ORDER BY starts_at`, now, now.Add(-maxDuration))
	if err != nil {
		return nil, fmt.Errorf("query current plans: %w", err)
	}
	return pgx.CollectRows(rows, func(row pgx.CollectableRow) (Plan, error) { return scanPlan(row) })
}

// Join locks the plan row so joins to the same plan run one at a time, then
// checks the rules against the participants committed so far.
func (s *PostgresStore) Join(ctx context.Context, id string, participant Participant, now time.Time) (Plan, error) {
	var joined Plan
	err := pgx.BeginFunc(ctx, s.pool, func(tx pgx.Tx) error {
		// Waits here while another transaction holds the lock.
		var locked string
		err := tx.QueryRow(ctx, "SELECT id FROM plans WHERE id = $1 FOR UPDATE", id).Scan(&locked)
		if errors.Is(err, pgx.ErrNoRows) {
			return errNotFound
		}
		if err != nil {
			return fmt.Errorf("lock plan: %w", err)
		}

		// Read participants in a new statement, after acquiring the lock.
		// Under READ COMMITTED each statement sees the data committed when
		// it starts; reading them in the locking statement would use a
		// snapshot taken before waiting and miss the joins that held the
		// lock, letting the plan exceed its limit.
		p, err := getPlan(ctx, tx, id)
		if err != nil {
			return err
		}
		if err := p.canJoin(participant.UserID, now); err != nil {
			return err
		}
		_, err = tx.Exec(ctx,
			"INSERT INTO plan_participants (plan_id, user_id, zone_id) VALUES ($1, $2, $3)",
			id, participant.UserID, participant.Zone.ID)
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" { // unique_violation
			return errAlreadyJoined
		}
		if err != nil {
			return fmt.Errorf("insert participant: %w", err)
		}
		p.Participants = append(p.Participants, participant)
		joined = p
		return nil
	})
	return joined, err
}

// querier is satisfied by both the pool and a transaction.
type querier interface {
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

func getPlan(ctx context.Context, q querier, id string) (Plan, error) {
	p, err := scanPlan(q.QueryRow(ctx, selectPlans+" WHERE id = $1", id))
	if errors.Is(err, pgx.ErrNoRows) {
		return Plan{}, errNotFound
	}
	if err != nil {
		return Plan{}, fmt.Errorf("get plan: %w", err)
	}
	return p, nil
}

func scanPlan(row pgx.Row) (Plan, error) {
	var (
		p                          Plan
		activityID, zoneID, status string
		description                *string
		durationMinutes            int
		limit                      *int
		userIDs, userZones         []string
	)
	err := row.Scan(&p.ID, &activityID, &p.Title, &description, &zoneID, &p.Place,
		&p.StartsAt, &durationMinutes, &limit, &p.CreatorID, &status, &userIDs, &userZones)
	if err != nil {
		return Plan{}, err
	}
	if len(userIDs) != len(userZones) {
		return Plan{}, fmt.Errorf("plan %s: %d participants but %d zones", p.ID, len(userIDs), len(userZones))
	}
	p.Duration = time.Duration(durationMinutes) * time.Minute
	p.Participants = make([]Participant, len(userIDs))
	for i, id := range userIDs {
		p.Participants[i] = Participant{UserID: id, Zone: zoneOrID(userZones[i])}
	}
	p.Activity = activityOrID(activityID)
	p.Zone = zoneOrID(zoneID)
	p.Status = Status(status)
	p.StartsAt = p.StartsAt.UTC()
	if description != nil {
		p.Description = *description
	}
	if limit != nil {
		p.MaxParticipants = *limit
	}
	return p, nil
}

// activityOrID resolves a stored activity id, keeping plans readable if the
// catalog drops an id they still reference.
func activityOrID(id string) Activity {
	if a, ok := findActivity(id); ok {
		return a
	}
	return Activity{ID: id, Name: text{id, id}}
}

func zoneOrID(id string) Zone {
	if z, ok := findZone(id); ok {
		return z
	}
	return Zone{ID: id, Name: id}
}
