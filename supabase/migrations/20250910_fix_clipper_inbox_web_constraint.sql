-- Fix the clipper_inbox table to accept 'web' as a valid source_type
-- This is required for the web clipper extension to work

-- First, drop the existing constraint if it exists
ALTER TABLE public.clipper_inbox 
DROP CONSTRAINT IF EXISTS clipper_inbox_source_type_check;

-- Add the new constraint that allows both 'email_in' and 'web'
ALTER TABLE public.clipper_inbox 
ADD CONSTRAINT clipper_inbox_source_type_check 
CHECK (source_type IN ('email_in', 'web'));

-- Add a comment explaining the constraint
COMMENT ON CONSTRAINT clipper_inbox_source_type_check ON public.clipper_inbox 
IS 'Ensures source_type is either email_in (for inbound emails) or web (for web clipper)';
