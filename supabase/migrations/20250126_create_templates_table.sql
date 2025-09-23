-- Create a proper templates table in Supabase
-- This provides complete separation between notes and templates

-- Create templates table
CREATE TABLE IF NOT EXISTS public.templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Template content (encrypted)
  title_enc TEXT NOT NULL,
  body_enc TEXT NOT NULL,
  tags_enc TEXT, -- JSON array, encrypted
  
  -- Template metadata
  is_system BOOLEAN NOT NULL DEFAULT FALSE, -- System templates vs user templates
  category TEXT NOT NULL DEFAULT 'personal', -- work, personal, meeting, etc.
  description_enc TEXT, -- Short description, encrypted
  icon TEXT DEFAULT 'description', -- Icon identifier
  sort_order INTEGER DEFAULT 1000, -- Display order (lower = higher priority)
  
  -- Additional encrypted properties
  props_enc TEXT, -- JSON object for extensibility
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Soft delete
  deleted BOOLEAN NOT NULL DEFAULT FALSE,
  
  -- Unique constraint to prevent duplicates
  CONSTRAINT unique_user_template UNIQUE(user_id, id)
);

-- Create indexes for performance
CREATE INDEX idx_templates_user_id ON public.templates(user_id);
CREATE INDEX idx_templates_user_system ON public.templates(user_id, is_system);
CREATE INDEX idx_templates_deleted ON public.templates(deleted);
CREATE INDEX idx_templates_category ON public.templates(category);

-- Enable RLS
ALTER TABLE public.templates ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can only see their own templates
CREATE POLICY "Users can view own templates" ON public.templates
  FOR SELECT USING (auth.uid() = user_id);

-- Users can create their own templates (but not system templates)
CREATE POLICY "Users can create templates" ON public.templates
  FOR INSERT WITH CHECK (auth.uid() = user_id AND is_system = FALSE);

-- Users can update their own non-system templates
CREATE POLICY "Users can update own templates" ON public.templates
  FOR UPDATE USING (auth.uid() = user_id AND is_system = FALSE)
  WITH CHECK (auth.uid() = user_id AND is_system = FALSE);

-- Users can delete their own non-system templates
CREATE POLICY "Users can delete own templates" ON public.templates
  FOR DELETE USING (auth.uid() = user_id AND is_system = FALSE);

-- Function to get template statistics
CREATE OR REPLACE FUNCTION public.get_template_stats(p_user_id UUID)
RETURNS TABLE (
  total_templates BIGINT,
  system_templates BIGINT,
  user_templates BIGINT,
  categories JSONB
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COUNT(*)::BIGINT as total_templates,
    COUNT(*) FILTER (WHERE is_system = TRUE)::BIGINT as system_templates,
    COUNT(*) FILTER (WHERE is_system = FALSE)::BIGINT as user_templates,
    jsonb_object_agg(category, count) as categories
  FROM (
    SELECT category, COUNT(*) as count
    FROM public.templates
    WHERE user_id = p_user_id AND deleted = FALSE
    GROUP BY category
  ) cat_counts;
END;
$$;

-- Function to copy a template (for versioning or sharing in future)
CREATE OR REPLACE FUNCTION public.copy_template(
  p_template_id UUID,
  p_new_title TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_new_id UUID;
  v_user_id UUID;
BEGIN
  -- Get the current user
  v_user_id := auth.uid();
  
  -- Create a copy of the template
  INSERT INTO public.templates (
    user_id,
    title_enc,
    body_enc,
    tags_enc,
    is_system,
    category,
    description_enc,
    icon,
    sort_order,
    props_enc
  )
  SELECT 
    v_user_id,
    COALESCE(p_new_title, title_enc || ' (Copy)'),
    body_enc,
    tags_enc,
    FALSE, -- User template, not system
    category,
    description_enc,
    icon,
    sort_order + 1,
    props_enc
  FROM public.templates
  WHERE id = p_template_id
    AND user_id = v_user_id
    AND deleted = FALSE
  RETURNING id INTO v_new_id;
  
  RETURN v_new_id;
END;
$$;

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_template_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_templates_updated_at
  BEFORE UPDATE ON public.templates
  FOR EACH ROW
  EXECUTE FUNCTION public.update_template_updated_at();

-- Comment on table
COMMENT ON TABLE public.templates IS 'Stores note templates separately from notes for better organization and performance';
