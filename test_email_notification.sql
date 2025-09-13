-- Simulate email received notification
INSERT INTO notification_logs (user_id, event_type, title, body, data, status)
VALUES (
    auth.uid(),
    'email_received',
    'New Email',
    'You have a new email in your inbox',
    '{"inbox_id": "test_inbox_123", "from": "test@example.com"}'::jsonb,
    'pending'
);
