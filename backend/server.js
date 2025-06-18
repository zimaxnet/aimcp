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
