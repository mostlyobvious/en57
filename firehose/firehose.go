package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"os"

	"github.com/jackc/pgx/v5"
)

const channel = "en57.events_appended"

type Event struct {
	ID   string
	Type string
	Data []byte
}

func main() {
	ctx := context.Background()
	databaseURL := os.Getenv("DATABASE_URL")
	fmt.Fprintf(os.Stderr, "Connecting to %s\n", databaseURL)
	conn, err := pgx.Connect(ctx, databaseURL)
	if err != nil {
		exitf("Unable to connect to database: %v", err)
	}
	defer conn.Close(ctx)

	if _, err := conn.Exec(ctx, "LISTEN "+pgx.Identifier{channel}.Sanitize()); err != nil {
		exitf("Unable to listen for events: %v", err)
	}
	lastPosition, err := currentPosition(ctx, conn)
	if err != nil {
		exitf("Unable to read current event position: %v", err)
	}
	for {
		if err := printNewEvents(ctx, conn, &lastPosition); err != nil {
			exitf("Unable to fetch events: %v", err)
		}
		if _, err := conn.WaitForNotification(ctx); err != nil {
			exitf("Unable to wait for notification: %v", err)
		}
	}
}

func currentPosition(ctx context.Context, conn *pgx.Conn) (int64, error) {
	var position int64
	err := conn.QueryRow(ctx, "SELECT COALESCE(MAX(position), 0) FROM en57.events").Scan(&position)
	return position, err
}

func printNewEvents(ctx context.Context, conn *pgx.Conn, lastPosition *int64) error {
	rows, err := conn.Query(ctx, `
SELECT position, id, type, data
FROM en57.events
WHERE position > $1
ORDER BY position`, *lastPosition)
	if err != nil {
		return err
	}
	defer rows.Close()

	for rows.Next() {
		var position int64
		var event Event
		if err := rows.Scan(&position, &event.ID, &event.Type, &event.Data); err != nil {
			return err
		}
		formattedEvent, err := formatEvent(event)
		if err != nil {
			return err
		}
		fmt.Println(formattedEvent)
		*lastPosition = position
	}
	return rows.Err()
}

func formatEvent(event Event) (string, error) {
	decodedData, err := decodeJSON(event.Data)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%s, %s, %v", event.ID, event.Type, decodedData), nil
}

func decodeJSON(data []byte) (any, error) {
	if data == nil {
		return nil, nil
	}

	var decodedData any
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.UseNumber()
	if err := decoder.Decode(&decodedData); err != nil {
		return nil, err
	}
	return decodedData, nil
}

func exitf(format string, args ...any) {
	fmt.Fprintf(os.Stderr, format+"\n", args...)
	os.Exit(1)
}
