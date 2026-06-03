# Diagrama de componentes de la app Flutter

@startuml
!theme plain
skinparam componentStyle rectangle
skinparam linetype ortho
skinparam shadowing false

' --- MODO OSCURO (Fondo, Texto y Flechas) ---
skinparam backgroundColor #1E1E1E
skinparam defaultFontColor #E0E0E0
skinparam arrowColor #858585
skinparam arrowFontColor #B0B0B0

' --- CONFIGURACIÓN DE ESPACIADO ---
skinparam nodesep 70
skinparam ranksep 120
skinparam package {
    Padding 50
}

' --- Paleta de colores Dark Mode Profesional ---
skinparam package {
    BackgroundColor #252525
    BorderColor #666666
    FontColor #FFFFFF
}
skinparam component {
    BackgroundColor #0D2B45
    BorderColor #4AA9FF
    FontColor #FFFFFF
}
skinparam database {
    BackgroundColor #14331C
    BorderColor #4CAF50
    FontColor #FFFFFF
}
skinparam cloud {
    BackgroundColor #3E1F00
    BorderColor #FFA000
    FontColor #FFFFFF
}

' --- COMPONENTES EXTERNOS ---
cloud "Firebase Auth" as fbAuth
cloud "FCM" as fcm
cloud "Google Maps Platform" as gmaps
database "Cloud Firestore" as firestore
database "Firebase RTDB" as rtdb
component "API REST FastAPI" as api #311B92 

' --- APP MÓVIL (MÓDULOS DE DOMINIO) ---
package "App Móvil Flutter (Dominios Principales)" {
    component "Identity & Access\n(Autenticación, Sesión, Perfil)" as iam
    component "Presence\n(Tracking GPS en vivo)" as pres
    component "Dispatching\n(Mapas, Raites, Estancias)" as disp
    component "Safety & Community\n(Reportes, Zonas de Riesgo)" as saf
    component "Shared Core\n(Notificaciones, Suscripciones)" as shared
}

' --- RELACIONES INTERNAS (Lógica de App) ---
iam -right-> disp : "Habilita UI por Rol"
disp -down-> pres : "Consume telemetría GPS"
disp -right-> saf : "Muestra/Crea marcadores"
shared -left-> disp : "\nDispara rutas UI"

' --- RELACIONES EXTERNAS ---
iam -up-> fbAuth : "SDK"
iam ---> api : "Sincroniza permisos"

pres ---> rtdb : "WebSockets "
pres ---> firestore : "Guarda última ubi."

disp ---> gmaps : "Maps SDK"
disp ---> api : "REST (Transacciones)"
disp ---> firestore : "Streams (Lectura UI)"

saf ---> api : "REST (Crear/Votar reportes)"
saf ---> firestore : "Streams (Lectura marcadores)"

shared -up-> fcm : "FCM SDK"
shared ---> api : "REST (Reglas suscripción)"

@enduml

# Diagrama de componentes de la api Pyhton

@startuml
!theme plain
skinparam componentStyle rectangle
skinparam linetype ortho
skinparam shadowing false

' --- MODO OSCURO (Fondo, Texto y Flechas) ---
skinparam backgroundColor #1E1E1E
skinparam defaultFontColor #E0E0E0
skinparam arrowColor #858585
skinparam arrowFontColor #B0B0B0

' --- CONFIGURACIÓN DE ESPACIADO ---
skinparam nodesep 70
skinparam ranksep 80
skinparam package {
    Padding 30
    BackgroundColor #252525
    BorderColor #666666
    FontColor #FFFFFF
}
skinparam component {
    BackgroundColor #0D2B45
    BorderColor #4AA9FF
    FontColor #FFFFFF
}
skinparam database {
    BackgroundColor #14331C
    BorderColor #4CAF50
    FontColor #FFFFFF
}
skinparam cloud {
    BackgroundColor #3E1F00
    BorderColor #FFA000
    FontColor #FFFFFF
}

' --- CLIENTE EXTERNO ---
component "App Móvil Flutter\n(Cliente)" as app #311B92

' --- EXTERNAL SYSTEMS ---
cloud "Firebase Auth" as fbAuth
database "Cloud Firestore" as firestore
cloud "FCM" as fcm

' --- API FASTAPI (DOMINIOS) ---
package "API REST FastAPI (Dominios Principales)" {
    component "Identity & Access\n(Auth, Perfiles)" as iam
    component "Dispatching\n(Paradas, Raites, Estancias)" as disp
    component "Safety & Community\n(Zonas de riesgo, Reportes, Lotes)" as saf
    
    component "Shared / Infrastructure\n(Auth Middleware, FirestoreService, Notificaciones)" as shared
}

' --- RELACIONES CLIENTE -> API ---
app -down-> iam : "HTTPS + JWT\n"
app -down-> disp : "HTTPS + JWT\n"
app -down-> saf : "HTTPS + JWT\n"

' --- RELACIONES INTERNAS API ---
iam -down-> shared : "Validación y acceso a datos"
disp -down-> shared : "Validación y acceso a datos"
saf -down-> shared : "Validación y acceso a datos"

' --- RELACIONES API -> FIREBASE ---
shared -left-> fbAuth : "Verifica JWT"
shared -down-> firestore : "Lectura/Escritura (gRPC)"
shared -right-> fcm : "Envía Push"

@enduml