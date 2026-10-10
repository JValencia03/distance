package plans

// Activity is an entry of the predefined activity catalog used to organize
// and discover plans.
type Activity struct {
	ID   string
	Name text
}

// Zone is a predefined area used as a coarse reference location. Its center
// coordinates stay on the server so clients never handle precise positions.
// Zone names are proper nouns and are not translated.
type Zone struct {
	ID   string  `json:"id"`
	Name string  `json:"name"`
	Lat  float64 `json:"-"`
	Lng  float64 `json:"-"`
}

var activities = []Activity{
	{ID: "reading", Name: text{"Leer", "Reading"}},
	{ID: "walking", Name: text{"Caminar", "Walking"}},
	{ID: "running", Name: text{"Correr", "Running"}},
	{ID: "coffee", Name: text{"Tomar café", "Coffee"}},
	{ID: "studying", Name: text{"Estudiar", "Studying"}},
	{ID: "gym", Name: text{"Ir al gimnasio", "Gym"}},
	{ID: "gaming", Name: text{"Jugar videojuegos", "Video games"}},
	{ID: "photography", Name: text{"Fotografía", "Photography"}},
	{ID: "eating", Name: text{"Comer", "Eating out"}},
	{ID: "exploring", Name: text{"Explorar la ciudad", "Exploring the city"}},
}

// Placeholder zones (Bogotá) until the product chooses its launch city.
var zones = []Zone{
	{ID: "usaquen", Name: "Usaquén", Lat: 4.6946, Lng: -74.0309},
	{ID: "chapinero", Name: "Chapinero", Lat: 4.6486, Lng: -74.0628},
	{ID: "teusaquillo", Name: "Teusaquillo", Lat: 4.6327, Lng: -74.0794},
	{ID: "candelaria", Name: "La Candelaria", Lat: 4.5981, Lng: -74.0758},
	{ID: "suba", Name: "Suba", Lat: 4.7412, Lng: -74.0841},
	{ID: "engativa", Name: "Engativá", Lat: 4.7066, Lng: -74.1146},
	{ID: "fontibon", Name: "Fontibón", Lat: 4.6783, Lng: -74.1415},
	{ID: "kennedy", Name: "Kennedy", Lat: 4.6281, Lng: -74.1468},
}

func findActivity(id string) (Activity, bool) {
	for _, a := range activities {
		if a.ID == id {
			return a, true
		}
	}
	return Activity{}, false
}

func findZone(id string) (Zone, bool) {
	for _, z := range zones {
		if z.ID == id {
			return z, true
		}
	}
	return Zone{}, false
}
