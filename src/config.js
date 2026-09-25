// Conexión a Supabase.
// La clave "anon" es pública por diseño: va en el navegador de todos modos.
// Lo que protege los datos son las políticas RLS de la base (ver supabase/migrations).
// ⚠ En la PoC las políticas dejan leer y escribir sin login: usar solo con datos de prueba.
export const SUPABASE_URL = 'https://dhfelywlwqvsitoibfgn.supabase.co';
export const SUPABASE_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRoZmVseXdsd3F2c2l0b2liZmduIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAzMDUyMzcsImV4cCI6MjEwNTg4MTIzN30.yHTwRH0mzQpI6gWFBCeEb6uJf4tFJTKIFwOBXvcsphw';

// Zona horaria de la casa: define qué es "hoy" sin importar la del dispositivo.
export const TZ = 'America/Argentina/Buenos_Aires';

// Umbrales de alertas (documento funcional §5.4)
export const ALERTS = {
  hoursWithoutWalk: 9,
  hoursWithoutPoop: 24,
  foodDaysWarning: 5,
  lowMoodDays: 3,
};
