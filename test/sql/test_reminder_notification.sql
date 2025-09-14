-- Simulate reminder due notification
INSERT INTO notification_logs (user_id, event_type, title, body, data, status)
VALUES (
    auth.uid(),
    'reminder_due',
    'Reminder',
    'Your reminder is due now',
    '{"note_id": "test_note_101", "reminder_id": "reminder_202"}'::jsonb,
    'pending'
);
