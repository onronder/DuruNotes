-- Simulate note shared notification
INSERT INTO notification_logs (user_id, event_type, title, body, data, status)
VALUES (
    auth.uid(),
    'note_shared',
    'Note Shared',
    'Someone shared a note with you',
    '{"note_id": "test_note_789", "shared_by": "friend@example.com"}'::jsonb,
    'pending'
);
