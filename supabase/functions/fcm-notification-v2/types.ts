import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

export type NotificationStatus = 'pending' | 'processing' | 'delivered' | 'failed';
export type NotificationPriority = 'normal' | 'high' | 'critical';
export type DevicePlatform = 'android' | 'ios' | 'web';

export interface NotificationTemplate {
  title?: string;
  body?: string;
  subtitle?: string;
  image_url?: string;
  click_action?: string;
  icon?: string;
  color?: string;
  sound?: string;
  badge?: number;
  badge_icon?: string;
  ttl?: number;
  category?: string;
  background?: boolean;
  actions?: Array<{
    action: string;
    title: string;
    icon?: string;
  }>;
}

export interface NotificationEvent {
  id: string;
  user_id: string;
  event_type: string;
  priority: NotificationPriority;
  payload: Record<string, unknown>;
  collapse_key?: string;
  tag?: string;
  status: NotificationStatus;
  notification_templates?: {
    push_template?: NotificationTemplate;
  };
}

export interface UserDevice {
  device_id: string;
  user_id: string;
  push_token: string;
  platform: DevicePlatform;
  device_model?: string;
  os_version?: string;
  app_version?: string;
  is_active: boolean;
  last_seen_at?: string;
  created_at: string;
}

export interface DeliveryResult {
  success: boolean;
  error?: string;
  messageIndex: number;
}

export interface NotificationUpdate {
  status: NotificationStatus;
  updated_at: string;
  delivered_at?: string;
  error_message?: string;
  metadata?: Record<string, unknown>;
}

export interface BatchProcessingResult {
  processed: number;
  delivered: number;
  failed: number;
  errors: string[];
}

// Re-export for convenience
export type { SupabaseClient };
