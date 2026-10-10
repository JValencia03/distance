package plans

import (
	"context"
	"errors"
	"fmt"
	"sync"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// AvatarStore persists the avatars users customized. Users without a saved
// avatar get defaultAvatar; see avatarsFor.
type AvatarStore interface {
	// Avatar returns the saved avatar of userID, and false if there is none.
	Avatar(ctx context.Context, userID string) (Avatar, bool, error)
	SaveAvatar(ctx context.Context, userID string, a Avatar) error
	// Avatars returns the saved avatars of userIDs; users without one are
	// absent from the map.
	Avatars(ctx context.Context, userIDs []string) (map[string]Avatar, error)
}

// avatarsFor returns an avatar for every user in userIDs, saved or default.
func avatarsFor(ctx context.Context, store AvatarStore, userIDs []string) (map[string]Avatar, error) {
	saved, err := store.Avatars(ctx, userIDs)
	if err != nil {
		return nil, err
	}
	result := make(map[string]Avatar, len(userIDs))
	for _, id := range userIDs {
		if a, ok := saved[id]; ok {
			result[id] = a
		} else {
			result[id] = defaultAvatar(id)
		}
	}
	return result, nil
}

// MemoryAvatarStore keeps avatars in memory. Data is lost on restart.
type MemoryAvatarStore struct {
	mu      sync.RWMutex
	avatars map[string]Avatar
}

func NewMemoryAvatarStore() *MemoryAvatarStore {
	return &MemoryAvatarStore{avatars: map[string]Avatar{}}
}

func (s *MemoryAvatarStore) Avatar(_ context.Context, userID string) (Avatar, bool, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	a, ok := s.avatars[userID]
	return a, ok, nil
}

func (s *MemoryAvatarStore) SaveAvatar(_ context.Context, userID string, a Avatar) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.avatars[userID] = a
	return nil
}

func (s *MemoryAvatarStore) Avatars(_ context.Context, userIDs []string) (map[string]Avatar, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	result := map[string]Avatar{}
	for _, id := range userIDs {
		if a, ok := s.avatars[id]; ok {
			result[id] = a
		}
	}
	return result, nil
}

// PostgresAvatarStore persists avatars in the user_avatars table.
type PostgresAvatarStore struct {
	pool *pgxpool.Pool
}

func NewPostgresAvatarStore(pool *pgxpool.Pool) *PostgresAvatarStore {
	return &PostgresAvatarStore{pool: pool}
}

func (s *PostgresAvatarStore) Avatar(ctx context.Context, userID string) (Avatar, bool, error) {
	var a Avatar
	err := s.pool.QueryRow(ctx,
		"SELECT skin, body_color, skin_tone, accessory FROM user_avatars WHERE user_id = $1", userID,
	).Scan(&a.Skin, &a.BodyColor, &a.SkinTone, &a.Accessory)
	if errors.Is(err, pgx.ErrNoRows) {
		return Avatar{}, false, nil
	}
	if err != nil {
		return Avatar{}, false, fmt.Errorf("get avatar: %w", err)
	}
	return a, true, nil
}

func (s *PostgresAvatarStore) SaveAvatar(ctx context.Context, userID string, a Avatar) error {
	_, err := s.pool.Exec(ctx, `
		INSERT INTO user_avatars (user_id, skin, body_color, skin_tone, accessory)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (user_id) DO UPDATE
		SET skin = EXCLUDED.skin, body_color = EXCLUDED.body_color,
		    skin_tone = EXCLUDED.skin_tone, accessory = EXCLUDED.accessory,
		    updated_at = now()`,
		userID, a.Skin, a.BodyColor, a.SkinTone, a.Accessory)
	if err != nil {
		return fmt.Errorf("save avatar: %w", err)
	}
	return nil
}

func (s *PostgresAvatarStore) Avatars(ctx context.Context, userIDs []string) (map[string]Avatar, error) {
	result := map[string]Avatar{}
	if len(userIDs) == 0 {
		return result, nil
	}
	rows, err := s.pool.Query(ctx, `
		SELECT user_id, skin, body_color, skin_tone, accessory
		FROM user_avatars WHERE user_id = ANY($1)`, userIDs)
	if err != nil {
		return nil, fmt.Errorf("query avatars: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var (
			id string
			a  Avatar
		)
		if err := rows.Scan(&id, &a.Skin, &a.BodyColor, &a.SkinTone, &a.Accessory); err != nil {
			return nil, fmt.Errorf("scan avatar: %w", err)
		}
		result[id] = a
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("query avatars: %w", err)
	}
	return result, nil
}
