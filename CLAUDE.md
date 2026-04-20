# GoRide Driver — App Flutter Motorista

## Sobre o projeto
App mobile para motoristas do GoRide.
Backend: `http://89.116.73.59:8082/api`
Repositório: https://github.com/PortalAlenquer/goride-driver

## Stack
- Flutter + Dart
- go_router (navegação)
- dio + flutter_secure_storage (API + token)
- google_maps_flutter + geolocator (mapas)
- firebase_core + firebase_auth + cloud_firestore + firebase_messaging
- web_socket_channel (WebSocket Reverb)
- cached_network_image, url_launcher, image_picker

## Infraestrutura
- API Base: `http://89.116.73.59:8082/api`
- Storage: `http://89.116.73.59:8082/storage`
- WebSocket Reverb: `ws://89.116.73.59:8083/app/goride2-key`
- Firebase: Firestore para chat, FCM para notificações push

## Estrutura
lib/
main.dart
core/
api/api_client.dart
constants/api_constants.dart
models/
ride_model.dart
user_model.dart
services/
auth_service.dart
chat_service.dart
home_service.dart              — loadDriverData, getPendingRides, updateLocation
profile_service.dart
ride_service.dart
support_service.dart
websocket_service.dart
theme/app_theme.dart
utils/app_router.dart
features/
auth/
splash_screen.dart             — valida /auth/me, verifica role==driver
login_screen.dart
register_screen.dart           — multi-step com onboarding de tarifas
onboarding_screen.dart
home/
home_screen.dart               — mapa + toggle online + heatmap + corridas
widgets/
home_bottom_panel.dart       — painel inferior com status e saldo
home_ride_request_sheet.dart — sheet de nova corrida (aceitar/recusar)
ride/
ride_detail_screen.dart        — tela principal de corrida ativa (mapa + status)
widgets/
ride_action_cards.dart       — cards de ação por status
ride_header_btn.dart         — botões do header (chat, etc)
ride_passenger_card.dart     — card com dados do passageiro
ride_status_stepper.dart     — stepper de status da corrida
chat/
chat_screen.dart
profile/
profile_screen.dart
change_password_screen.dart
ride_history_screen.dart
wallet_screen.dart             — saldo + depósito Asaas + extrato
support_screen.dart            — tarifa + contato franquia + plataforma
vehicle_screen.dart            — gerenciamento de veículos
cnh_screen.dart                — upload e gestão de CNH

## Fluxo principal do motorista
splash → home_screen (offline)
→ toggle online
→ polling 8s: GET /driver/rides/pending
→ nova corrida → HomeRideRequestSheet (20s countdown)
→ aceitar → PATCH /rides/{id}/accept → ride_detail_screen
→ status: accepted → driver_arriving → in_progress → completed → payment_confirmed
→ ride_detail_screen gerencia todo o fluxo com WS

## Endpoints utilizados
POST  /auth/login
POST  /auth/register
GET   /auth/me
POST  /auth/logout
PUT   /profile
PUT   /profile/password
POST  /profile/avatar
GET   /driver/me                    ← perfil motorista com veículos e wallet
PUT   /driver/status                ← toggle online/offline
PUT   /driver/payment-methods       ← atualizar formas de pagamento aceitas
GET   /driver/rides/pending         ← corridas disponíveis (polling 8s)
POST  /rides/{id}/accept            ← aceitar corrida
POST  /rides/{id}/reject            ← recusar corrida
PUT   /rides/{id}/status            ← atualizar status da corrida
GET   /rides/{id}                   ← detalhes da corrida
GET   /rides                        ← histórico
POST  /rides/driver/location        ← atualizar localização em tempo real
GET   /wallet/balance
GET   /wallet/transactions
POST  /payments/deposit             ← depósito via Asaas (motorista)
GET   /vehicles                     ← listar veículos
POST  /vehicles                     ← adicionar veículo
PUT   /vehicles/{id}                ← atualizar veículo
POST  /fcm/token                    ← salvar token FCM
POST  /broadcasting/auth            ← auth canal WS privado
GET   /driver/fee-by-location       ← tarifa + contato franquia (suporte)

## WebSocket — Canal Privado
- Canal: `private-ride.{rideId}`
- Auth: `POST /broadcasting/auth` com token Sanctum
- Eventos recebidos: `ride.status.updated`, `driver.location.updated`
- Eventos enviados pelo backend: ao aceitar, atualizar status, cancelar

## Regras de negócio

### Toggle Online
- Bloqueia se: sem veículo cadastrado (`needsVehicle`) ou sem aprovação (`needsApproval`)
- Ao ficar online: envia localização imediatamente
- Localização: stream contínuo a cada 10m ou 5s — só envia quando online

### Nova Corrida
- Polling: `GET /driver/rides/pending` a cada 8s quando online
- Sheet de corrida: countdown 20s para aceitar
- Vibração + haptic ao receber nova corrida
- Ao aceitar: navega para `ride_detail_screen`
- Ao recusar: chama `POST /rides/{id}/reject`

### Fluxo de Status da Corrida
accepted → driver_arriving → in_progress → completed → payment_confirmed
- Cada status tem card de ação específico em `ride_action_cards.dart`
- `completed`: confirma pagamento conforme método (cash/pix/card/wallet)
- `payment_confirmed`: debita taxa da plataforma na carteira do motorista

### Wallet do Motorista
- Sistema pré-pago — motorista mantém saldo positivo
- Limite negativo padrão: R$ -50,00
- Taxa cobrada por corrida (fixa ou % do valor)
- Depósito via Asaas (PIX)
- Saldo baixo → alerta no painel

### Chat
- Firebase Firestore — mesmo padrão do passageiro
- `readerRole: 'driver'` para marcar mensagens como lidas
- Badge de não lidas no botão de chat

### Back-to-Back
- Motorista pode receber próxima corrida enquanto está em andamento
- `_nextRide` exibido como banner quando `status == in_progress`

## Padrões de código
- `withValues(alpha: x)` em vez de `withOpacity(x)`
- `LocationSettings(accuracy: LocationAccuracy.high)`
- Singleton: `AuthService()`, `ApiClient()`, `ChatService()`
- Polling separado: usuário 60s, corridas 8s
- `if (!mounted) return` após todos os awaits

## Cores (AppTheme)
```dart
primary   = Color(0xFF6366F1)  // Roxo
secondary = Color(0xFF10B981)  // Verde
danger    = Color(0xFFEF4444)  // Vermelho
warning   = Color(0xFFF59E0B)  // Amarelo
dark      = Color(0xFF1F2937)
gray      = Color(0xFF6B7280)
```

## Rotas
/splash, /login, /register, /onboarding
/home
/ride-detail/:id
/profile, /change-password, /ride-history
/wallet, /support, /vehicles, /cnh
/chat/:rideId

## Pendentes / A revisar
1. FCM — notificar motorista sobre nova corrida disponível (backend já tem `notifyNewRide`)
2. Depósito Asaas — testar credenciais e fluxo completo
3. `flutter analyze` — revisar e zerar issues
4. Alinhar `RideModel` com versão atualizada do passageiro
5. Tela de veículos — verificar CRUD completo
6. Perfil — adicionar upload de foto igual ao passageiro