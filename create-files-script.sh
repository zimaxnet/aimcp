#!/bin/bash

echo "🚀 Creating AI MCP System files..."

# Create directory structure
mkdir -p frontend/src/{components,config,services,utils}
mkdir -p frontend/public
mkdir -p backend/src/{services,middleware,routes,utils}
mkdir -p backend/temp
mkdir -p deployment
mkdir -p docs
mkdir -p scripts

# Create root package.json
cat > package.json << 'EOF'
{
  "name": "ai-mcp-system",
  "version": "1.0.0",
  "description": "AI system with React frontend, Azure B2C auth, and 100+ MCP server integrations",
  "keywords": ["ai", "mcp", "azure", "react", "llm", "chatbot"],
  "author": "Zimax Team",
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "https://github.com/zimaxnet/ai-mcp-system.git"
  },
  "workspaces": ["frontend", "backend"],
  "scripts": {
    "dev": "concurrently \"npm run dev:backend\" \"npm run dev:frontend\"",
    "dev:backend": "cd backend && npm run dev",
    "dev:frontend": "cd frontend && npm start",
    "build": "npm run build:frontend && npm run build:backend",
    "build:frontend": "cd frontend && npm run build",
    "build:backend": "cd backend && npm run build",
    "test": "npm run test:frontend && npm run test:backend",
    "test:frontend": "cd frontend && npm test",
    "test:backend": "cd backend && npm test",
    "docker:build": "docker-compose build",
    "docker:up": "docker-compose up",
    "docker:down": "docker-compose down"
  },
  "devDependencies": {
    "concurrently": "^8.2.2"
  }
}
EOF

# Create backend package.json
cat > backend/package.json << 'EOF'
{
  "name": "ai-mcp-backend",
  "version": "1.0.0",
  "description": "Backend API for AI MCP System",
  "main": "server.js",
  "type": "module",
  "scripts": {
    "dev": "nodemon server.js",
    "start": "node server.js",
    "test": "jest",
    "build": "echo 'No build step needed for Node.js'"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "multer": "^1.4.5-lts.1",
    "dotenv": "^16.3.1",
    "@azure/cosmos": "^4.0.0",
    "@azure/storage-file-share": "^12.17.0",
    "@azure/msal-node": "^2.6.4",
    "@modelcontextprotocol/sdk": "^0.3.0",
    "openai": "^4.28.0",
    "anthropic": "^0.18.0",
    "axios": "^1.6.0",
    "ws": "^8.16.0",
    "sharp": "^0.33.0",
    "pdf-parse": "^1.1.1",
    "@microsoft/microsoft-graph-client": "^3.0.7",
    "helmet": "^7.1.0",
    "rate-limiter-flexible": "^4.0.1"
  },
  "devDependencies": {
    "nodemon": "^3.0.2",
    "jest": "^29.7.0"
  }
}
EOF

# Create backend .env.example
cat > backend/.env.example << 'EOF'
# Azure B2C Configuration
AZURE_CLIENT_ID=your-client-id
AZURE_CLIENT_SECRET=your-client-secret
AZURE_TENANT_ID=your-tenant-id
AZURE_TENANT_NAME=your-tenant-name
POLICY_NAME=your-policy-name

# Cosmos DB Configuration
COSMOS_ENDPOINT=https://your-cosmos-account.documents.azure.com:443/
COSMOS_KEY=your-cosmos-key
COSMOS_DATABASE=ai-system

# Azure Storage Configuration
AZURE_STORAGE_CONNECTION_STRING=your-storage-connection-string
AZURE_FILE_SHARE_NAME=ai-files

# LLM API Keys
OPENAI_API_KEY=your-openai-key
ANTHROPIC_API_KEY=your-anthropic-key

# MCP Server API Keys
BRAVE_API_KEY=your-brave-api-key
GITHUB_TOKEN=your-github-token
GOOGLE_DRIVE_CLIENT_ID=your-google-drive-client-id
GOOGLE_DRIVE_CLIENT_SECRET=your-google-drive-client-secret
SLACK_BOT_TOKEN=your-slack-token
TODOIST_API_TOKEN=your-todoist-token
GMAIL_CLIENT_ID=your-gmail-client-id
GMAIL_CLIENT_SECRET=your-gmail-client-secret
NOTION_API_KEY=your-notion-key

# File paths
ALLOWED_FILES_PATH=/tmp/allowed-files

# Server Configuration
PORT=3001
EOF

# Create backend server.js
cat > backend/server.js << 'EOF'
import express from 'express';
import cors from 'cors';
import multer from 'multer';
import dotenv from 'dotenv';
import { MCPServerManager } from './src/services/MCPServerManager.js';
import { LLMOrchestrator } from './src/services/LLMOrchestrator.js';
import { MemoryService } from './src/services/MemoryService.js';
import { AuthMiddleware } from './src/middleware/AuthMiddleware.js';
import { FileService } from './src/services/FileService.js';

dotenv.config();

const app = express();
const upload = multer({ dest: 'temp/' });

// Initialize services
const mcpManager = new MCPServerManager();
const llmOrchestrator = new LLMOrchestrator();
const memoryService = new MemoryService();
const authMiddleware = new AuthMiddleware();
const fileService = new FileService();

app.use(cors());
app.use(express.json());

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// Initialize MCP servers
console.log('Initializing MCP servers...');
await mcpManager.initializeAllServers();

// Chat endpoint
app.post('/api/chat', 
  authMiddleware.validateToken, 
  upload.array('attachments'), 
  async (req, res) => {
    try {
      const { message, userId } = req.body;
      const files = req.files || [];
      
      // Process attachments
      const processedFiles = await Promise.all(
        files.map(file => fileService.processFile(file))
      );
      
      // Get conversation memory
      const conversationHistory = await memoryService.getConversationHistory(userId);
      
      // Create enriched context
      const context = {
        message,
        files: processedFiles,
        history: conversationHistory,
        userId,
        availableTools: mcpManager.getAvailableTools(),
        userProfile: req.user
      };
      
      // Process through LLM orchestrator
      const response = await llmOrchestrator.processRequest(context, mcpManager);
      
      // Save to memory
      await memoryService.saveInteraction(userId, {
        input: { message, files: processedFiles },
        output: response,
        timestamp: new Date(),
        reasoning: response.metadata?.reasoning
      });
      
      res.json(response);
    } catch (error) {
      console.error('Chat error:', error);
      res.status(500).json({ error: 'Internal server error', details: error.message });
    }
  }
);

// Get conversation history
app.get('/api/conversations/:userId', authMiddleware.validateToken, async (req, res) => {
  try {
    const { userId } = req.params;
    const history = await memoryService.getConversationHistory(userId);
    res.json(history);
  } catch (error) {
    res.status(500).json({ error: 'Failed to get conversation history' });
  }
});

// Get available MCP tools
app.get('/api/tools', authMiddleware.validateToken, async (req, res) => {
  try {
    const tools = mcpManager.getAvailableTools();
    res.json(tools);
  } catch (error) {
    res.status(500).json({ error: 'Failed to get tools' });
  }
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/api/health`);
});
EOF

# Create frontend package.json
cat > frontend/package.json << 'EOF'
{
  "name": "ai-mcp-frontend",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "@azure/msal-browser": "^3.7.1",
    "@azure/msal-react": "^2.0.2",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-scripts": "5.0.1",
    "react-markdown": "^9.0.1",
    "react-syntax-highlighter": "^15.5.0",
    "lucide-react": "^0.263.1",
    "tailwindcss": "^3.3.0",
    "autoprefixer": "^10.4.14",
    "postcss": "^8.4.24"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "eslintConfig": {
    "extends": [
      "react-app",
      "react-app/jest"
    ]
  },
  "browserslist": {
    "production": [
      ">0.2%",
      "not dead",
      "not op_mini all"
    ],
    "development": [
      "last 1 chrome version",
      "last 1 firefox version",
      "last 1 safari version"
    ]
  },
  "proxy": "http://localhost:3001"
}
EOF

# Create .gitignore
cat > .gitignore << 'EOF'
# Dependencies
node_modules/
*/node_modules/

# Environment variables
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Build outputs
build/
dist/
*/build/
*/dist/

# Logs
logs
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Runtime data
pids
*.pid
*.seed
*.pid.lock

# Coverage directory used by tools like istanbul
coverage/
*.lcov

# nyc test coverage
.nyc_output

# Dependency directories
node_modules/
jspm_packages/

# Optional npm cache directory
.npm

# Optional eslint cache
.eslintcache

# Temporary folders
tmp/
temp/
*/temp/

# Editor directories and files
.vscode/
.idea/
*.swp
*.swo
*~

# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Azure
.azure/

# Docker
docker-compose.override.yml
EOF

echo "✅ Basic files created! Now creating service files..."

# Create backend services directory and files
mkdir -p backend/src/services
mkdir -p backend/src/middleware

# Create a basic MCP Server Manager
cat > backend/src/services/MCPServerManager.js << 'EOF'
export class MCPServerManager {
  constructor() {
    this.servers = new Map();
    this.tools = new Map();
    this.resources = new Map();
  }

  async initializeAllServers() {
    console.log('📡 Initializing MCP servers...');
    
    // For now, we'll create a simple mock implementation
    // TODO: Add real MCP server integrations when @modelcontextprotocol/sdk is available
    
    const mockTools = [
      {
        server: 'memory',
        name: 'store_memory',
        description: 'Store information in memory',
        inputSchema: {
          type: 'object',
          properties: {
            key: { type: 'string' },
            value: { type: 'string' }
          }
        }
      },
      {
        server: 'web_search',
        name: 'search_web',
        description: 'Search the web for information',
        inputSchema: {
          type: 'object',
          properties: {
            query: { type: 'string' }
          }
        }
      }
    ];

    this.tools.set('mock', mockTools);
    console.log(`✅ Initialized mock MCP servers with ${mockTools.length} tools`);
    
    return mockTools;
  }

  async callTool(serverName, toolName, arguments_) {
    console.log(`🔧 Calling tool ${toolName} on ${serverName} with args:`, arguments_);
    
    // Mock implementation
    switch (toolName) {
      case 'store_memory':
        return { success: true, stored: arguments_ };
      case 'search_web':
        return { 
          success: true, 
          results: [`Mock search result for: ${arguments_.query}`]
        };
      default:
        return { success: false, error: 'Tool not found' };
    }
  }

  getAvailableTools() {
    const allTools = [];
    for (const [serverName, tools] of this.tools.entries()) {
      for (const tool of tools) {
        allTools.push({
          server: tool.server,
          name: tool.name,
          description: tool.description,
          inputSchema: tool.inputSchema
        });
      }
    }
    return allTools;
  }

  async cleanup() {
    console.log('🧹 Cleaning up MCP servers...');
  }
}
EOF

# Create LLM Orchestrator
cat > backend/src/services/LLMOrchestrator.js << 'EOF'
export class LLMOrchestrator {
  constructor() {
    // Initialize with mock implementation for now
    this.providers = {
      'mock-llm': 'Mock Provider'
    };
  }

  async processRequest(context, mcpManager) {
    const { message, files, history, userId, availableTools } = context;
    
    console.log(`🤖 Processing request for user ${userId}: ${message}`);
    
    // Phase 1: Simple response for now
    const response = {
      content: `Hello! I received your message: "${message}". I have access to ${availableTools.length} tools and can see ${files.length} files. This is a mock response while we set up the full system.`,
      metadata: {
        toolsUsed: [],
        reasoning: 'Mock reasoning - full LLM integration coming soon'
      }
    };

    return {
      response: response.content,
      metadata: response.metadata
    };
  }
}
EOF

# Create Memory Service
cat > backend/src/services/MemoryService.js << 'EOF'
export class MemoryService {
  constructor() {
    // Mock implementation - will use CosmosDB in production
    this.conversations = new Map();
  }

  async saveInteraction(userId, interaction) {
    console.log(`💾 Saving interaction for user ${userId}`);
    
    if (!this.conversations.has(userId)) {
      this.conversations.set(userId, []);
    }
    
    this.conversations.get(userId).push({
      id: Date.now(),
      ...interaction
    });
  }

  async getConversationHistory(userId, limit = 50) {
    console.log(`📜 Getting conversation history for user ${userId}`);
    
    const history = this.conversations.get(userId) || [];
    return history.slice(-limit);
  }

  async searchMemory(userId, query, limit = 10) {
    console.log(`🔍 Searching memory for user ${userId}: ${query}`);
    
    const history = this.conversations.get(userId) || [];
    return history.filter(item => 
      JSON.stringify(item).toLowerCase().includes(query.toLowerCase())
    ).slice(0, limit);
  }
}
EOF

# Create Auth Middleware
cat > backend/src/middleware/AuthMiddleware.js << 'EOF'
export class AuthMiddleware {
  constructor() {
    // Mock implementation for development
    this.mockMode = true;
  }

  validateToken = (req, res, next) => {
    if (this.mockMode) {
      // Mock user for development
      req.user = {
        id: 'mock-user-123',
        name: 'Development User',
        email: 'dev@zimax.net'
      };
      return next();
    }

    // TODO: Implement real Azure B2C token validation
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'No token provided' });
    }

    // Validate token with Azure B2C
    next();
  };
}
EOF

# Create File Service
cat > backend/src/services/FileService.js << 'EOF'
import fs from 'fs/promises';

export class FileService {
  constructor() {
    console.log('📁 File service initialized');
  }

  async processFile(file) {
    console.log(`📄 Processing file: ${file.originalname}`);
    
    const fileInfo = {
      name: file.originalname,
      size: file.size,
      type: file.mimetype,
      path: file.path
    };

    try {
      // Basic text extraction
      if (file.mimetype.startsWith('text/')) {
        fileInfo.content = await fs.readFile(file.path, 'utf-8');
      } else {
        fileInfo.content = `Binary file: ${file.mimetype}`;
      }

      return fileInfo;
    } catch (error) {
      console.error('Error processing file:', error);
      return fileInfo;
    } finally {
      // Clean up temporary file
      try {
        await fs.unlink(file.path);
      } catch (error) {
        console.error('Error cleaning up temp file:', error);
      }
    }
  }
}
EOF

echo "✅ All files created successfully!"
echo ""
echo "📝 Next steps:"
echo "1. cd backend && cp .env.example .env"
echo "2. Edit backend/.env with your API keys"
echo "3. npm install (from root directory)"
echo "4. npm run dev"
echo ""
echo "🚀 The system will start with mock implementations that you can extend!"
