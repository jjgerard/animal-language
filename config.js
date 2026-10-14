// Animal Language — connection settings.
// Both values come from Supabase: Project Settings -> API.
// The anon key is designed to be public (it only ever has the limited access that
// schema.sql grants), so it is safe to commit. NEVER put the service_role key here.
// Leave these blank to run in local-only mode (contributions stay in this browser).
window.BB_CONFIG = {
  supabaseUrl: '',   // e.g. 'https://abcdefgh.supabase.co'
  anonKey: ''        // the "anon public" key
};
