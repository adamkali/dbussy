package types

type Config struct {
	Connections map[string]Connection `yaml:"connections"`
    Scripts     string `yaml:"scripts"`
}

type Connection struct {
    Name     string `yaml:"name"`
    Host     string `yaml:"host"`
	Database string `yaml:"database"`
    Username string `yaml:"username"`
	Password string `yaml:"password"`
}
