-- Simulate web clip saved notification
INSERT INTO notification_logs (user_id, event_type, title, body, data, status)
VALUES (
    auth.uid(),
    'web_clip_saved',
    'Web Clip Saved',
    'Your web clip has been saved successfully',
    '{"note_id": "test_note_456", "url": "https://example.com"}'::jsonb,
    'pending'
);
