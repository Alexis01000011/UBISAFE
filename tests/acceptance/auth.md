# Acceptance E2E — F2: Identity & Access

**CU:** Auth (Registro, Login, Logout)  
**Fase:** F2  
**SDD:** SDD_FASE2_PASO25_UBISAFE.md §5.3.1 | SDD_FASE4_UBISAFE.md §8.4

## Precondiciones

- Firebase emuladores corriendo: `firebase emulators:start --project demo-ubisafe`
- API corriendo: `cd ubisafe_api && uvicorn main:app --reload`
- App en dispositivo/emulador Android con `flutter run`

---

## Escenarios

### A1 — App sin sesión va a Welcome

1. Limpiar datos de la app (o usar emulador limpio).
2. Abrir la app.
3. **Esperado:** Splash aparece brevemente → navega a pantalla de Bienvenida.

---

### A2 — Registro BUYER va a /home/buyer

1. En Welcome → "Crear cuenta".
2. Ingresar nombre y teléfono → "Siguiente".
3. Seleccionar rol **Comprador**, ingresar email y contraseña (≥6 chars) → "Crear cuenta".
4. **Esperado:**
   - Spinner mientras se crea la cuenta.
   - Navega a `/home/buyer` (MapScreenBuyer).
   - En Firestore emulador: `users/{uid}` tiene `role: "BUYER"`, `name`, `phone`, `created_at`, `updated_at`.

---

### A3 — Registro VENDOR va a /home/vendor

1. Repetir A2 pero seleccionando rol **Vendedor**.
2. **Esperado:** Navega a `/home/vendor` (MapScreenVendor).
3. En Firestore: `users/{uid}` tiene `role: "VENDOR"`.

---

### A4 — Sesión persistente: cerrar y reabrir va al home correcto

1. Completar A2 (BUYER logueado).
2. Cerrar la app completamente (kill process).
3. Volver a abrir la app.
4. **Esperado:** Splash → navega directamente a `/home/buyer` sin pasar por Welcome ni Login.

---

### A5 — Drawer → Cerrar sesión va a Welcome

1. Con sesión activa, abrir el Drawer.
2. **Esperado:** El Drawer muestra el nombre del usuario y el rol (ej. "BUYER").
3. Tocar "Cerrar sesión".
4. **Esperado:** Navega a pantalla de Bienvenida. Drawer ya no muestra datos de usuario.

---

### A6 — Login con credenciales incorrectas → error inline

1. En Welcome → "Iniciar sesión".
2. Ingresar email incorrecto o contraseña incorrecta → "Entrar".
3. **Esperado:** SnackBar con mensaje de error. Permanece en LoginScreen. No navega.

---

### A7 — Login con credenciales correctas → home según rol

1. Tener un usuario creado (via A2 o A3).
2. Cerrar sesión (A5).
3. Login con las credenciales correctas.
4. **Esperado:** Navega a `/home/buyer` si rol BUYER, `/home/vendor` si VENDOR.

---

## Definición de éxito

Todos los escenarios A1–A7 pasan sin errores en consola ni crashes.  
El campo `role` en Firestore emulador coincide con el rol elegido en signup.
