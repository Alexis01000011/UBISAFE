# Referencias de Arquitectura — UBISAFE
## Sistemas y artículos con decisiones similares a nuestros ADRs

**Proyecto:** UBISAFE — Los Borbotones  
**Elaborado por:** Miguel (Tech Lead) — Iteración 2  
**Fecha:** 25/04/2026  
**Propósito:** Mapear cada Architecture Decision Record del SDD2 con sistemas reales y artículos académicos o técnicos que tomaron decisiones arquitectónicas análogas. Útil para justificar decisiones en presentaciones, defensa del SDD o investigación relacionada.

---

## Sistemas globalmente similares a UBISAFE

Antes de ir por ADR, estos son los proyectos cuya arquitectura *completa* (no solo una decisión) se asemeja más a UBISAFE:

### 1. Safetipin (India, 2013 — activo)
La referencia más cercana a UBISAFE en misión y técnica. App de seguridad urbana con georeferenciación de reportes comunitarios, auditoría de espacios públicos y scoring de zonas por parámetros de seguridad. Desplegada en Delhi, Bogotá y Nairobi; sus datos han impulsado mejoras de infraestructura reales (iluminación en 70% de puntos oscuros identificados en Delhi).

Comparte con UBISAFE: crowdsourcing de reportes georreferenciados, validación comunitaria, zonas de riesgo en radio, orientación a poblaciones vulnerables.

- Artículo académico: Viswanath, K. et al., **"SafetiPin: an innovative mobile app to collect data on women's safety in Indian cities"** (2014). ResearchGate: https://www.researchgate.net/publication/274265668

### 2. Ushahidi (Kenya, 2008 — open source activo)
Plataforma open source de crowdsourcing para mapeo de crisis. Los usuarios reportan eventos con geolocalización; un segundo grupo de voluntarios los modera, verifica y clasifica antes de que sean publicados en el mapa. Arquitectura de dos colecciones lógicas (reportes brutos vs. reportes verificados), validación en dos pasos y geometría de puntos/radios.

Comparte con UBISAFE: dos fases de datos (reporte → validación), modelo de moderación comunitaria, zonas circulares, múltiples fuentes de ingesta (web, SMS, API).

- Artículo: Okolloh, O., **"Ushahidi, or 'testimony': Web 2.0 tools for crowdsourcing crisis information"** (2009). IIED. https://www.iied.org/sites/default/files/pdfs/migrate/G02842.pdf
- Caso de estudio: ResearchGate — **"Innovating in the midst of crisis: A case study of Ushahidi"**: https://www.researchgate.net/publication/231537244

### 3. Waze (Israel/Google, 2006 — activo)
App de navegación con reportes de incidentes enviados por la comunidad y validados mediante confirmaciones de otros conductores en la misma ruta. El algoritmo asigna mayor confiabilidad a los usuarios que históricamente reportan con precisión — un sistema de reputación implícito que extiende el modelo de votación simple que usa UBISAFE.

Comparte con UBISAFE: reporte comunitario + validación por votación de proximidad, geometría circular para activar confirmaciones, notificaciones push a usuarios en radio relevante.

- Caso de estudio Harvard: **"Waze: Leveraging the Crowd to Find Your Way"** — Digital Innovation & Transformation, Harvard Business School: https://d3.harvard.edu/platform-digit/submission/waze-leveraging-the-crowd-to-find-your-way/
- Paper académico: Bartin, B. et al., **"Evaluating the Reliability, Coverage, and Added Value of Crowdsourced Traffic Incident Reports from Waze"** (2018). *Transportation Research Record*. https://www.researchgate.net/publication/326916618

### 4. Gojek (Indonesia, 2015 — activo)
Super-app construida originalmente para formalizar el mercado informal de mototaxis (ojek) en Indonesia: conecta vendedores de servicios informales con compradores vía GPS, matching en tiempo real y notificaciones push. Empezó como monolito Python antes de escalar a microservicios. Usa Google Maps Platform y Firebase en sus capas de tracking y notificaciones.

Comparte con UBISAFE: formalización de economía informal, matching comprador-vendedor por GPS, monolito como punto de partida, Google Maps + FCM.

- Paper académico (socioeconómico/técnico): Kibaroğlu, O., **"Gojek as Infrastructure: Street Smart Technology of Indonesia"** (2021). Academia.edu: https://www.academia.edu/73128855
- Análisis HBS: **"Go-Jek or Go Home"** — Technology and Operations Management, HBS: https://rctom.hbs.org/submission/go-jek-or-go-home

---

## ADR #1 — Monolito FastAPI vs. Microservicios

**Decisión UBISAFE:** Backend FastAPI como monolito modular. Justificación: MVP, equipo pequeño, sin carga de producción real que justifique la complejidad operativa de microservicios.

### Sistemas que tomaron la misma decisión

**Shopify** mantuvo un monolito Ruby on Rails durante más de una década de hiper-crecimiento antes de migrar partes selectas. Su arquitectura interna usa dominios separados dentro del mismo proceso. **Stack Overflow** sirve millones de peticiones por día desde un puñado de servidores con una arquitectura monolítica bien optimizada. **Basecamp** ha mantenido un monolito Rails activamente y su CTO, DHH, es uno de los defensores más conocidos del patrón.

### Artículos y papers

- Fowler, M., **"MonolithFirst"** (2015). Argumento canónico: construir primero el monolito y migrar solo cuando el problema es real. https://martinfowler.com/bliki/MonolithFirst.html

- Fowler, M. & Lewis, J., **"Microservices"** (2014). Artículo que popularizó los microservicios *y* enumera las precondiciones que deben cumplirse antes de adoptarlos. Leerlo en contexto del MonolithFirst aclara por qué UBISAFE eligió bien. https://martinfowler.com/articles/microservices.html

- Fritzsch, J. et al., **"From Monolith to Microservices: A Classification of Refactoring Approaches"** (2019). arxiv. Clasifica 10 enfoques de decomposición; útil para cuando UBISAFE escale. https://arxiv.org/pdf/1807.10059

- Villamizar, M. et al., **"From Monolithic Systems to Microservices: A Comparative Study of Performance"** (2020). *Applied Sciences*, MDPI. Benchmarks empíricos de latencia, throughput y costo entre ambas arquitecturas. https://www.mdpi.com/2076-3417/10/17/5797

---

## ADR #2 — GPS directo a Firebase RTDB (sin pasar por FastAPI)

**Decisión UBISAFE:** El cliente Flutter escribe la posición GPS directamente en Firebase RTDB, evitando el round-trip por FastAPI. Esto reduce latencia de tracking y elimina un punto de fallo.

### Sistemas que tomaron la misma decisión

**Uber** (arquitectura temprana, 2010-2013) escribía la posición de los drivers directamente en su base de datos de presencia sin pasar por el backend de negocio; la separación entre el "plano de presencia" y el "plano de negocio" es un patrón documentado en su engineering blog. **Lyft** usó Firebase RTDB explícitamente para tracking de conductores en su versión inicial. Los patrones de **live driver tracking** con Firebase son el caso de uso estrella de RTDB.

### Artículos y recursos técnicos

- Firebase Engineering, **"Firebase Realtime Database"** — documentación oficial de arquitectura y modelo de datos. https://firebase.google.com/docs/database

- AFI Engineering Blog, **"Building Live Driver Tracking Backend"** — describe exactamente el patrón de escribir GPS directo a RTDB desde cliente móvil con listeners en tiempo real. https://blog.afi.io/blog/building-live-driver-tracking-backend/

- Saigon Technology, **"Realtime Location Tracking using Firebase"** — caso de estudio de producción con la misma arquitectura que UBISAFE: Flutter + Firebase RTDB + Google Maps. https://saigontechnology.com/case-studies/realtime-location-tracking-using-firebase/

---

## ADR #3 — Persistencia Políglota: Cloud Firestore + Firebase RTDB

**Decisión UBISAFE:** Firestore para datos estructurados con ciclo de vida complejo (stop_requests, rides, community_reports, users) y RTDB para datos de presencia GPS efímeros de alta frecuencia. Cada base de datos hace exactamente lo que hace mejor.

### Sistemas que tomaron la misma decisión

**Twitter** usa una combinación de MySQL, Manhattan (KV store propio), Cassandra y Hadoop, cada uno para un tipo de dato diferente. **Airbnb** usa MySQL para reservas, S3 para imágenes, Redis para sesiones y Elasticsearch para búsquedas. **Netflix** usa Cassandra para estado de visualización, EVCache (Redis) para sesiones, y S3 para contenido. El patrón en todos estos casos es idéntico al de UBISAFE a escala diferente.

### Artículos y papers

- Fowler, M., **"PolyglotPersistence"** (2011). El artículo original que acuñó el término. https://martinfowler.com/bliki/PolyglotPersistence.html

- Grachev, E. et al., **"Revisiting Polyglot Persistence: From Principles to Practice"** (2022). *International Journal of Advanced Computer Science and Applications*, Vol. 13(5). Paper académico completo disponible en: https://thesai.org/Downloads/Volume13No5/Paper_99-Revisiting_Polyglot_Persistence_From_Principles_to_Practice.pdf

- Hlúšek, T. et al., **"Polyglot Persistence in Heterogeneous NoSQL Database Systems with Python"** (2025). *Springer Lecture Notes in Networks and Systems*. Cubre combinaciones de NoSQL en Python — el stack más cercano a UBISAFE (FastAPI + Firestore + RTDB). https://link.springer.com/chapter/10.1007/978-3-031-98287-3_28

---

## ADR #4 — State Management en Flutter: Riverpod

**Decisión UBISAFE:** Riverpod 2.x como solución de state management en Flutter, descartando Provider (limitaciones de contexto), Bloc (boilerplate excesivo) y GetX (antipatrones de acoplamiento).

### Sistemas que tomaron la misma decisión

Riverpod es el state manager más adoptado en apps Flutter de producción en 2024-2026 según la encuesta oficial de Flutter. Apps como **Inverso** (fintech), **Etebase** (personal data) y múltiples apps del ecosistema Google han adoptado Riverpod. El propio repositorio oficial de Flutter tiene ejemplos con Riverpod.

### Artículos y recursos técnicos

- Riverpod oficial, **"Why Riverpod?"** — argumenta los problemas de Provider que Riverpod resuelve (contexto, testing, async). https://riverpod.dev/

- ssoad, **"Flutter Riverpod Clean Architecture: The Ultimate Production-Ready Template"** (2024). Dev.to. Muestra cómo se combina Riverpod con Clean Architecture en proyectos reales. https://dev.to/ssoad/flutter-riverpod-clean-architecture-the-ultimate-production-ready-template-for-scalable-apps-gdh

- Youssef, M., **"State Management in Flutter: Provider vs Riverpod vs Bloc"** — comparativa técnica de las tres alternativas que consideró UBISAFE. https://ms3byoussef.medium.com/state-management-in-flutter-provider-vs-riverpod-vs-bloc-333795f0df22

- Flutter oficial, **"Approaches to State Management"** — panorama completo de opciones reconocidas. https://docs.flutter.dev/data-and-backend/state-mgmt/options

---

## ADR #6 — Modelo de Validación Comunitaria: Votación Simple (umbral 3)

**Decisión UBISAFE:** Cada reporte se valida mediante votos `confirm`/`dismiss`; al alcanzar 3 votos de un tipo, el reporte cambia de estado (`confirmed`/`dismissed`). No hay sistema de reputación en Iter. 2.

### Sistemas que tomaron la misma decisión

**Waze** usa confirmaciones de usuarios en la misma ruta para validar reportes de accidentes o policía. **Wikipedia** usa votaciones de consenso para borrar artículos (Articles for Deletion) con umbrales de participación. **iNaturalist** requiere 2/3 de votos de identificación de especie para marcar una observación como "Research Grade". **OpenStreetMap** usa el sistema de changeset voting para revertir cambios vandálicos.

La diferencia clave de UBISAFE respecto a Waze es que no implementa aún reputación ponderada por historial — una extensión natural que Waze sí usa y que UBISAFE puede adoptar en Iter. 3.

### Artículos y papers

- Bartin et al., **"Evaluating the Reliability, Coverage, and Added Value of Crowdsourced Traffic Incident Reports from Waze"** (2018). *Transportation Research Record*. Analiza empíricamente la calidad de datos generados por un sistema de reporte+confirmación comunitaria — directamente aplicable a validar el diseño de ADR #6. https://www.researchgate.net/publication/326916618

- Goodchild, M.F., **"Citizens as Sensors: The World of Volunteered Geography"** (2007). *GeoJournal*, 69(4), 211-221. Paper seminal sobre calidad de datos geográficos generados por comunidades. Introduce el problema de sesgo geográfico y social que cualquier sistema de crowdsourcing como UBISAFE debe considerar. Referencia clásica en este dominio.

- Flanagin, A. & Metzger, M., **"The credibility of volunteered geographic information"** (2008). *GeoJournal*, 72, 137-148. Estudia cómo los usuarios evalúan la confiabilidad de datos aportados por la comunidad — base teórica del umbral de votos.

---

## ADR #7 — Geometría de Zonas: Círculos (GeoPoint + radio 15 m)

**Decisión UBISAFE:** Las zonas de riesgo se representan como círculo de radio fijo de 15 metros anclado en un GeoPoint. Los polígonos se difieren a Iter. 3.

### Sistemas que tomaron la misma decisión

**Google Maps** usa círculos como representación primaria en su Geofencing API (radio mínimo recomendado: 100-150 m para exteriores, reducible a 15-30 m en interiores). **Apple Find My** y **Life360** usan zonas circulares para alertas de entrada/salida. **Safetipin** representa sus safety scores en hexágonos H3 — una variación del círculo para cobertura continua del mapa.

El radio de 15 m de UBISAFE es más pequeño que el estándar de geofencing de Google (100 m) porque UBISAFE no usa el acelerómetro/GPS del OS para disparar eventos, sino que hace la comparación Haversine en servidor al recibir coordenadas — lo que elimina la limitación del radio mínimo de los geofences nativos de Android/iOS.

### Artículos y recursos técnicos

- Google Developers, **"Create and monitor geofences"** (Android). Documenta por qué el radio mínimo recomendado para geofences nativos es 100-150 m y las condiciones en que se reduce. https://developer.android.com/develop/sensors-and-location/location/geofencing

- Google Maps Platform, **"Trigger geofences client-side with Nav SDK"** — describe la arquitectura de geofence server-side vs. client-side (UBISAFE usa la variante server-side Haversine, que el artículo contrasta). https://developers.google.com/maps/architecture/navsdk-client-side-geofences

---

## ADR #10 — Cloud Functions como Orquestador de Eventos (Python gen2)

**Decisión UBISAFE:** Una Cloud Function Python gen2 actúa como trigger sobre `community_reports.onCreate` para detectar reportes duplicados en radio 100 m sin añadir latencia al flujo de usuario.

### Sistemas que tomaron la misma decisión

**Firebase-native apps** usan Cloud Functions para exactamente este patrón: lógica de negocio asíncrona que no debe bloquear la respuesta al usuario (envío de emails, agregación de contadores, detección de duplicados, fanout de notificaciones). **Duolingo** usa Cloud Functions para el procesamiento de XP y streaks asíncrono. **The New York Times** usó Firebase + Cloud Functions para la arquitectura de actualizaciones en tiempo real de su app de elecciones.

El patrón es análogo al uso de **AWS Lambda + DynamoDB Streams** o **Azure Functions + Cosmos DB trigger** en otros ecosistemas cloud.

### Artículos y papers

- Roberts, M., **"Serverless Architectures"** (2018). martinfowler.com. Artículo de referencia sobre arquitectura serverless y cuándo usar funciones como orquestadores de eventos. https://martinfowler.com/articles/serverless.html

- Hassan, H. et al., **"Rise of the Planet of Serverless Computing: A Systematic Review"** (2023). *ACM Transactions on Software Engineering and Methodology*. Revisión sistemática de 164 papers sobre serverless — incluye sección sobre event-driven triggers en Cloud Functions. https://dl.acm.org/doi/10.1145/3579643 (preprint: https://arxiv.org/pdf/2206.12275)

- Eismann, S. et al., **"Survey on serverless computing"** (2021). *Journal of Cloud Computing*, Springer. Cubre cold start, modelos de ejecución y patrones de uso en producción — el paper más citado en su categoría. https://journalofcloudcomputing.springeropen.com/articles/10.1186/s13677-021-00253-7

- Al-Alawi, M. et al., **"Event-Driven Design Patterns for Scalable Backend Infrastructure Using Serverless Functions and Cloud Message Brokers"** (2025). ResearchGate. Formaliza el patrón exacto que usa UBISAFE: Firestore trigger → Cloud Function → fanout asíncrono. https://www.researchgate.net/publication/394770288

---

## ADR #11 — Coexistencia de Dos Colecciones de Reportes

**Decisión UBISAFE:** `risk_zones` (zonas de riesgo permanentes, CU-03) y `community_reports` (reportes comunitarios validables con ciclo de vida, CU-05/06) son colecciones separadas en Firestore, cada una con su schema y reglas de seguridad propias.

### Sistemas que tomaron la misma decisión

**Twitter** separa tweets (contenido público inmutable) de direct messages (contenido privado con ciclo de vida), aunque ambos son "mensajes". **GitHub** separa issues de pull requests aunque ambos son tickets con comentarios. **Uber** separa trips de delivery orders aunque ambos son "rides". La separación de colecciones por comportamiento del ciclo de vida (no por similitud superficial de campos) es un patrón de Domain-Driven Design.

En términos de DDD: `risk_zones` y `community_reports` son **Aggregate Roots** distintos en bounded contexts distintos (Safety vs. Community) — la separación es consecuencia directa del diseño de dominios, no una decisión arbitraria de schema.

### Artículos y recursos técnicos

- Vernon, V., **"Implementing Domain-Driven Design"** (2013). Addison-Wesley. Cap. 10: Aggregates. Define cuándo dos entidades similares deben ser Aggregates separados vs. parte del mismo Aggregate. La regla de invariantes de negocio diferentes → Aggregates diferentes aplica exactamente al caso de UBISAFE.

- Evans, E., **"Domain-Driven Design: Tackling Complexity in the Heart of Software"** (2003). Addison-Wesley. El libro que introdujo Bounded Contexts, Aggregates y el modelo que justifica ADR #11.

---

## ADR Retro-A — Firebase Auth como Proveedor de Identidad

**Decisión UBISAFE:** Firebase Authentication (JWT + Google/email) en lugar de Auth0, Clerk o solución custom en FastAPI.

### Sistemas con la misma elección

La mayoría de startups y MVPs móviles que usan Firebase eligen Firebase Auth por defecto: **Canva** (en su etapa inicial), **Duolingo**, y miles de apps de la Play Store/App Store. Auth0 se elige cuando el proyecto requiere SSO enterprise, SAML o cumplimiento normativo (HIPAA/SOC2) — ninguna de estas condiciones aplica a UBISAFE en Iter. 1-2.

### Artículos y recursos técnicos

- Descope, **"Auth0 vs. Firebase: Which One Is Right for You?"** — comparativa técnica exhaustiva de ambas soluciones con tabla de decisión por caso de uso. https://www.descope.com/blog/post/auth0-vs-firebase

- Userfront, **"Auth0 vs Cognito vs Okta vs Firebase vs Userfront"** — panorama completo del ecosistema de identity providers con análisis de costo y complejidad. https://userfront.com/blog/auth-landscape

---

## ADR Retro-B — Google Maps Platform como Solución Cartográfica

**Decisión UBISAFE:** Google Maps SDK para Flutter (vs. Mapbox, OpenStreetMap/Leaflet) por cobertura en México y familiaridad del equipo. Riesgo de costo a escala declarado como deuda técnica DT-03.

### Sistemas con la misma elección y el mismo riesgo

**Uber**, **Lyft**, **Rappi** y **Gojek** usan Google Maps Platform en sus apps móviles de cara al usuario. El riesgo de costo a escala es real: en 2018, Google elevó precios un 1400% en algunos endpoints de la Maps API, lo que forzó a varias empresas a migrar a Mapbox (Airbnb migró en 2018 por exactamente este motivo).

### Artículos y recursos técnicos

- Google Maps Platform, **"Geofencing Architecture"** — documentación oficial de arquitectura para casos de uso de proximidad y zonas. https://developers.google.com/maps/architecture/navsdk-client-side-geofences

- Observación de mercado: cuando UBISAFE crezca, la referencia de migración es el caso público de **Airbnb → Mapbox** (2018), documentado en varios post-mortems de ingeniería de la compañía.

---

## ADR Retro-C — FCM como Canal Único de Push

**Decisión UBISAFE:** Firebase Cloud Messaging como única vía de notificaciones push. Android-only en Iter. 1; Iter. 2 añade 4 nuevos tipos de evento. iOS y web diferidos.

### Sistemas con la misma elección

FCM es el estándar de facto para push en apps Android. La decisión de diferir iOS no es atípica en proyectos latinoamericanos donde Android domina el mercado (México: ~80% Android). Ushahidi, Safetipin y la mayoría de apps de seguridad ciudadana en mercados emergentes arrancan con FCM exclusivo para Android.

### Artículos y recursos técnicos

- Firebase, **"Firebase Cloud Messaging Architecture"** — documento de arquitectura oficial que explica el modelo de tokens, topics y condition-based targeting que UBISAFE usa para notificar a usuarios en radio 4 km. https://firebase.google.com/docs/cloud-messaging

---

## Tabla resumen

| ADR | Decisión clave | Sistema análogo más cercano | Paper/artículo de referencia principal |
|---|---|---|---|
| #1 | Monolito FastAPI | Shopify (pre-2020), Gojek (inicial) | Fowler, "MonolithFirst" (2015) |
| #2 | GPS directo RTDB | Lyft (inicial), Uber early | AFI Blog: Live Driver Tracking |
| #3 | Polyglot Firestore+RTDB | Twitter, Airbnb, Netflix | Fowler, "PolyglotPersistence" (2011) |
| #4 | Riverpod | Flutter ecosystem estándar (2024+) | Flutter oficial state mgmt options |
| #6 | Votación simple umbral 3 | Waze, iNaturalist, Wikipedia | Bartin et al., *Transportation Research Record* (2018) |
| #7 | Zonas circulares radio 15m | Google Geofencing API, Life360 | Android Geofence docs (Google) |
| #10 | Cloud Functions trigger async | Duolingo, NYT elections app | Hassan et al., ACM TOSEM (2023) |
| #11 | Dos colecciones separadas | Twitter (tweets vs DMs), GitHub (issues vs PRs) | Evans, *DDD* (2003); Vernon, *IDDD* (2013) |
| Retro-A | Firebase Auth | Canva, Duolingo, miles de MVPs | Descope: Auth0 vs Firebase |
| Retro-B | Google Maps Platform | Uber, Rappi, Gojek | Google Maps Platform Architecture docs |
| Retro-C | FCM Android-first | Safetipin, Ushahidi (inicial) | Firebase FCM Architecture docs |

---

## Lectura recomendada por prioridad

Si solo hay tiempo para leer 3-5 referencias antes de una defensa o presentación, estas son las más impactantes:

1. **Fowler, "MonolithFirst"** — justifica directamente ADR #1. Lectura de 10 minutos, muy citado.
2. **Bartin et al. (2018)** — paper académico que valida empíricamente el modelo de votación comunitaria de ADR #6.
3. **Goodchild (2007), "Citizens as Sensors"** — marco teórico para toda la parte de crowdsourcing (ADRs #6, #7, #11).
4. **Hassan et al., ACM TOSEM (2023)** — revisión sistemática de serverless que respalda ADR #10.
5. **Safetipin paper de Viswanath (2014)** — el sistema más similar a UBISAFE en misión; su arquitectura y lecciones son directamente transferibles.
