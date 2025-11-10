# Real Product Size Backend

An Elixir Phoenix API backend for the Real Product Size AR app. Provides product crawling, 3D model generation, subscription management, and real-time WebSocket updates.

## 🚀 Features

### Core API
- **Product Management**: CRUD operations for products with dimensions
- **Multi-Platform Crawling**: AI-powered product data extraction from Amazon, IKEA, and more
- **Smart URL Categorization**: AR suitability filtering and product type detection
- **Intelligent Caching**: Time-based caching with automatic cleanup
- **Quality Validation**: Multi-layer validation for AR compatibility
- **Advanced Error Handling**: Graceful degradation and user feedback loops
- **3D Model Generation**: TriPo AI integration for 3D model creation
- **User Authentication**: JWT-based authentication system
- **Subscription System**: Usage tracking and feature gating with limits
- **Real-time Updates**: WebSocket integration for live data
- **Analytics Dashboard**: Comprehensive business intelligence and metrics

### AI Integration
- **Gemini AI**: Google's AI for product data extraction
- **Grok AI**: xAI's model for intelligent parsing
- **TriPo AI**: 3D model generation from product descriptions
- **Fallback Systems**: Automatic fallback to traditional crawling

### Database Features
- **PostgreSQL**: Primary database with comprehensive schema
- **Ecto ORM**: Type-safe database operations
- **Migrations**: Complete database schema management
- **Analytics**: Usage tracking and performance metrics

## 🏗️ Architecture

### Core Modules
```
lib/real_product_size_backend/
├── accounts/              # User management and authentication
├── products/              # Product CRUD and management
├── crawling/              # Multi-platform crawling and AI extraction
├── ar_sessions/           # AR session tracking
├── subscriptions/         # Subscription and usage management
├── user_products/         # User-product relationships
├── ai_crawler/           # AI-powered crawling services
├── url_validator/         # Multi-platform URL validation
├── url_categorizer/       # Smart categorization and AR suitability
├── product_cache/         # Intelligent caching system
├── product_validator/     # Quality validation and AR compatibility
├── error_handler/         # Advanced error handling and recovery
├── usage_analytics/       # Enhanced usage tracking and analytics
└── analytics_dashboard/   # Business intelligence and metrics
```

### Web Layer
```
lib/real_product_size_backend_web/
├── controllers/api/       # REST API controllers
├── live/                 # LiveView components
├── components/           # Reusable UI components
└── plugs/               # Authentication and middleware
```

## 🗄️ Database Schema

### Core Tables
- **users** - User accounts and authentication
- **products** - Product information with dimensions
- **user_products** - User-product relationships
- **ar_sessions** - AR usage tracking
- **crawling_history** - Crawling analytics and errors

### Subscription System
- **subscription_plans** - Available subscription tiers
- **user_subscriptions** - User subscription status
- **user_usage** - Usage tracking and limits

### Analytics & Monitoring
- **api_request_logs** - API request/response logging
- **error_tracking** - Error occurrence and resolution
- **system_performance_metrics** - System health monitoring

## 🛠️ Tech Stack

### Backend
- **Elixir 1.18.3** - Functional programming language
- **Phoenix 1.7** - Web framework with LiveView
- **Ecto** - Database wrapper and query builder
- **PostgreSQL** - Primary database
- **Oban** - Background job processing

### AI Services
- **Gemini API** - Google's AI for data extraction
- **Grok API** - xAI's model for intelligent parsing
- **OpenRouter API** - Multi-model AI router for flexible provider selection
- **TriPo API** - 3D model generation
- **HTTPoison** - HTTP client for API calls

### Development Tools
- **ExUnit** - Testing framework
- **Credo** - Code analysis
- **Dialyzer** - Static analysis
- **EctoDevLogger** - Database query logging

## 🚀 Quick Start

### Prerequisites
- Elixir 1.18.3+
- PostgreSQL 14+
- Node.js 18+ (for assets)

### Installation
```bash
# Clone and setup
cd /Users/bill/Documents/elixir/real_product_size_backend
mix deps.get
mix ecto.setup

# Start the server
mix phx.server
```

### Configuration
The app runs on `http://localhost:6800` by default.

## 🔧 Configuration

### Environment Variables
```bash
# Database
export DATABASE_URL="postgres://user:pass@localhost/real_product_size_backend_dev"

# AI Services
export GEMINI_API_KEY="your_gemini_key"
export GROK_API_KEY="your_grok_key"
export OPENROUTER_API_KEY="your_openrouter_key"
export TRIPO_API_KEY="your_tripo_key"

# JWT
export JWT_SECRET_KEY="your_jwt_secret"
```

### Development Settings
```elixir
# config/dev.exs
config :real_product_size_backend, :debug,
  skip_crawler: true,                    # Use mock data
  use_mock_product_data: true,           # Enable mock products
  mock_product_count: 20,                # Number of mock products
  log_crawling_details: true,            # Detailed logging
  log_ar_sessions: true,                 # AR session logging
  log_performance_metrics: true          # Performance tracking
```

## 📡 API Endpoints

### Products
- `GET /api/products` - List products with pagination
- `GET /api/products/:id` - Get product details
- `POST /api/products` - Create new product
- `POST /api/products/crawl` - Crawl product from any supported platform
- `GET /api/products/search` - Search products
- `GET /api/products/stats` - Get product statistics
- `GET /api/products/category/:category` - Get products by category
- `GET /api/products/brand/:brand` - Get products by brand
- `GET /api/products/user` - Get user's products

### Authentication
- `POST /api/auth/login` - User login
- `POST /api/auth/register` - User registration
- `POST /api/auth/refresh` - Refresh JWT token

### Subscriptions
- `GET /api/subscriptions/plans` - Get subscription plans
- `GET /api/subscriptions/current` - Get user subscription
- `POST /api/subscriptions/verify` - Verify purchase

### Usage Tracking
- `POST /api/usage/track` - Track user action
- `GET /api/usage/summary` - Get usage summary
- `POST /api/usage/check` - Check usage limits

### Analytics & Business Intelligence
- `GET /api/analytics/dashboard` - Get comprehensive dashboard data
- `GET /api/analytics/realtime` - Get real-time analytics
- `GET /api/analytics/user/:user_id` - Get user-specific analytics
- `GET /api/analytics/time-range` - Get analytics for time range
- `GET /api/analytics/crawling` - Get crawling performance metrics
- `GET /api/analytics/platforms` - Get platform-specific analytics
- `GET /api/analytics/errors` - Get error analytics and resolution
- `GET /api/analytics/business` - Get business metrics and KPIs
- `GET /api/analytics/performance` - Get performance metrics
- `GET /api/analytics/export` - Export analytics data
- `GET /api/analytics/user-usage` - Get user usage statistics
- `GET /api/analytics/platform-usage` - Get platform usage statistics
- `GET /api/analytics/subscriptions` - Get subscription statistics
- `GET /api/analytics/ar-suitability` - Get AR suitability statistics
- `GET /api/analytics/health` - Get system health status
- `GET /api/analytics/api-usage` - Get API usage statistics

## 🔌 WebSocket Events

### Connection
```javascript
const socket = new Phoenix.Socket("ws://localhost:6800/socket");
socket.connect();
```

### Channels
- `product:lobby` - Product updates
- `user:${user_id}` - User-specific events

### Events
- `product_updated` - Product data changes
- `crawling_complete` - Crawling finished
- `model_generated` - 3D model ready
- `usage_updated` - Usage limit changes

## 🧪 Testing

### Run Tests
```bash
# All tests
mix test

# Specific test files
mix test test/real_product_size_backend/products_test.exs
mix test test/real_product_size_backend/ai_crawler_test.exs

# With coverage
mix test --cover
```

### Test Database
```bash
# Reset test database
MIX_ENV=test mix ecto.reset

# Run migrations
MIX_ENV=test mix ecto.migrate
```

## 🔍 Development

### Database Management
```bash
# Create and migrate
mix ecto.create
mix ecto.migrate

# Reset database
mix ecto.reset

# Generate migration
mix ecto.gen.migration add_new_field

# Rollback migration
mix ecto.rollback
```

### Code Quality
```bash
# Format code
mix format

# Run linter
mix credo

# Run dialyzer
mix dialyzer
```

## 🚀 Deployment

### Production Build
```bash
# Compile for production
MIX_ENV=prod mix compile

# Run migrations
MIX_ENV=prod mix ecto.migrate

# Start server
MIX_ENV=prod mix phx.server
```

### Docker Support
```bash
# Build image
docker build -t real-product-size-backend .

# Run container
docker run -p 6800:6800 real-product-size-backend
```

## 📊 Monitoring

### Health Checks
- `GET /health` - Basic health check
- `GET /metrics` - System metrics
- `GET /status` - Detailed status

### Logging
- **Structured Logging**: JSON format for production
- **Request Logging**: All API requests logged
- **Error Tracking**: Comprehensive error logging
- **Performance Metrics**: Response time tracking

## 🔐 Security

### Authentication
- **JWT Tokens**: Secure API authentication
- **Token Refresh**: Automatic token renewal
- **Rate Limiting**: API request limiting
- **CORS**: Cross-origin request handling

### Data Protection
- **Input Validation**: All inputs validated
- **SQL Injection**: Ecto prevents SQL injection
- **XSS Protection**: Content sanitization
- **CSRF Protection**: Cross-site request forgery prevention

## 🎯 Current Status

### ✅ Completed
- Complete database schema with 15 tables
- Full API with authentication
- Multi-platform product crawling (Amazon, IKEA)
- Smart URL categorization and AR suitability filtering
- Intelligent caching with time-based expiration
- Quality validation and AR compatibility checking
- Advanced error handling with graceful degradation
- Subscription and usage tracking with limits
- WebSocket real-time updates
- Comprehensive analytics and business intelligence
- Background job processing
- User feedback loops for data correction

### 🔄 In Progress
- Additional e-commerce platform support
- Advanced AI model integration
- Performance optimizations

### 📋 Planned
- Redis caching layer (upgrade from ETS)
- Advanced rate limiting
- Multi-tenant support
- API versioning
- Machine learning for quality prediction

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Run the test suite
6. Submit a pull request

## 📄 License

This project is private and proprietary.

---

**Backend Ready!** 🎉 The API is fully functional and ready for production use with the Flutter frontend.