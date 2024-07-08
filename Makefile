# Target to run the Postgres container
run-postgres:
	docker compose -f containers/postgres.docker-compose.yml up -d

# Target to stop the Postgres container (optional)
stop-postgres:
	docker compose -f containers/postges.docker-compose.yml down

# Run python test program
run-script-after-server:
	@echo "Waiting for server to start..."
	@if [ -f server.pid ]; then  # Check if PID file exists
		python3 ./scripts/dbussy.test.py
	else
		sleep 10
	fi

# Run the server in the backgrond
run-server:
	gleam run & echo $!  # Run in background using '&'
	PID=$(gleam run)  # Capture PID of python process running 'server.py'
	echo "Server started with PID: ${PID}"
# Write PID to file (optional)
	echo ${PID} > server.pid

# Target to stop the server based on PID
stop-server:
	@if [ -f server.pid ]; then  # Check if PID file exists
		PID=$(cat server.pid)
		kill ${PID}
		echo "Server stopped with PID: ${PID}"
	else
		echo "Server PID file not found. No server to stop."
	fi

all: run-postgres run-server run-script-after-server
clean: stop-server stop-postgres
.PHONY: all clean
