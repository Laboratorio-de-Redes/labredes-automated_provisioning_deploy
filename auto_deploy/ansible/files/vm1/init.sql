-- Executado automaticamente no primeiro boot do PostgreSQL
CREATE TABLE IF NOT EXISTS agents (
    id            INTEGER PRIMARY KEY,
    hostname      VARCHAR NOT NULL,
    agent_type    VARCHAR NOT NULL,
    status        VARCHAR DEFAULT 'active',
    registered_at TIMESTAMP DEFAULT NOW(),
    last_seen     TIMESTAMP DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS host_metrics (
    id              SERIAL PRIMARY KEY,
    agent_id        INTEGER REFERENCES agents(id),
    cpu_percent     FLOAT,
    ram_percent     FLOAT,
    disk_percent    FLOAT,
    connections_tcp INTEGER DEFAULT 0,
    uptime_seconds  INTEGER DEFAULT 0,
    collected_at    TIMESTAMP DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS network_metrics (
    id             SERIAL PRIMARY KEY,
    agent_id       INTEGER REFERENCES agents(id),
    interface_name VARCHAR,
    vlan_id        INTEGER,
    bytes_in       BIGINT DEFAULT 0,
    bytes_out      BIGINT DEFAULT 0,
    packets_in     BIGINT DEFAULT 0,
    packets_out    BIGINT DEFAULT 0,
    collected_at   TIMESTAMP DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS network_flows (
    id          SERIAL PRIMARY KEY,
    src_ip      VARCHAR,
    dst_ip      VARCHAR,
    src_port    INTEGER,
    dst_port    INTEGER,
    protocol    VARCHAR,
    bytes       BIGINT DEFAULT 0,
    packets     BIGINT DEFAULT 0,
    duration_s  FLOAT DEFAULT 0,
    captured_at TIMESTAMP DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS inventory (
    id             SERIAL PRIMARY KEY,
    ip_address     VARCHAR UNIQUE NOT NULL,
    hostname       VARCHAR,
    mac_address    VARCHAR,
    os_fingerprint VARCHAR,
    open_ports     JSON DEFAULT '[]',
    services       JSON DEFAULT '[]',
    vlan           INTEGER,
    discovered_at  TIMESTAMP DEFAULT NOW(),
    updated_at     TIMESTAMP DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS events (
    id          SERIAL PRIMARY KEY,
    source      VARCHAR,
    event_type  VARCHAR,
    severity    VARCHAR DEFAULT 'info',
    description VARCHAR,
    extra_data  JSON DEFAULT '{}',
    created_at  TIMESTAMP DEFAULT NOW()
);
INSERT INTO agents (id, hostname, agent_type, status) VALUES
    (1,  'vm1',    'host',    'active'),
    (2,  'vm2',    'host',    'active'),
    (3,  'vm3',    'host',    'active'),
    (4,  'vm4',    'host',    'active'),
    (6,  'vm6',    'host',    'active'),
    (7,  'vm7',    'host',    'active'),
    (9,  'vm9',    'host',    'active'),
    (10, 'vm10',   'host',    'active'),
    (11, 'vm-sw1', 'network', 'active'),
    (12, 'vm-sw2', 'network', 'active')
ON CONFLICT DO NOTHING;
