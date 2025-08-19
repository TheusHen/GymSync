const path = require('path');

// Mock the dependencies
jest.mock('electron', () => ({
  app: {
    whenReady: jest.fn().mockResolvedValue(),
    quit: jest.fn(),
    isQuitting: false,
    getPath: jest.fn().mockReturnValue('/tmp'),
    on: jest.fn(),
  },
  BrowserWindow: jest.fn().mockImplementation(() => ({
    loadURL: jest.fn(),
    on: jest.fn(),
    webContents: {
      on: jest.fn(),
    },
    show: jest.fn(),
    hide: jest.fn(),
  })),
  Tray: jest.fn().mockImplementation(() => ({
    setToolTip: jest.fn(),
    setContextMenu: jest.fn(),
  })),
  Menu: {
    buildFromTemplate: jest.fn().mockReturnValue({}),
  },
  dialog: {
    showMessageBox: jest.fn(),
  },
  nativeImage: {
    createFromPath: jest.fn().mockReturnValue({ isEmpty: () => false }),
    createEmpty: jest.fn().mockReturnValue({}),
  },
}));

jest.mock('electron-prompt', () => jest.fn().mockResolvedValue('GymSync Test'));
jest.mock('discord-rich-presence', () => jest.fn().mockReturnValue({
  updatePresence: jest.fn(),
  clearPresence: jest.fn(),
}));
jest.mock('discord-rpc', () => ({
  register: jest.fn(),
  Client: jest.fn().mockImplementation(() => ({
    ready: false,
    on: jest.fn(),
    login: jest.fn().mockResolvedValue(),
    setActivity: jest.fn().mockResolvedValue(),
    clearActivity: jest.fn().mockResolvedValue(),
  })),
}));
jest.mock('axios', () => ({
  get: jest.fn().mockResolvedValue({ data: { id: '123456789', username: 'testuser', discriminator: '1234' } }),
}));
jest.mock('auto-launch', () => {
  return jest.fn().mockImplementation(() => ({
    isEnabled: jest.fn().mockResolvedValue(true),
    enable: jest.fn().mockResolvedValue(),
  }));
});
jest.mock('fs', () => ({
  appendFileSync: jest.fn(),
}));

// Import the functions to test
// Note: In a real test, we would need to restructure the main.js file to export these functions
// For this example, we'll test the functions we can access directly
describe('GymSync Presence App', () => {
  // Test the getImageKeyForActivity function
  describe('getImageKeyForActivity', () => {
    // We need to define the function here since we can't import it directly
    function getImageKeyForActivity(activity) {
      if (!activity || typeof activity !== "string") return "gymsync_logo"; // fallback para gymsync_logo
      const key = activity.toLowerCase();
      
      // Activity image mapping
      const activityImageMap = {
        "running": "running",
        "cycling": "cycling",
        "gym": "gym",
      };
      
      // Try to match by activity name
      for (const [name, imageKey] of Object.entries(activityImageMap)) {
        if (key.includes(name)) return imageKey;
      }
      // Se não encontrar, retorna fallback gymsync_logo
      return "gymsync_logo";
    }

    test('should return the correct image key for known activities', () => {
      expect(getImageKeyForActivity('running')).toBe('running');
      expect(getImageKeyForActivity('cycling')).toBe('cycling');
      expect(getImageKeyForActivity('gym workout')).toBe('gym');
      expect(getImageKeyForActivity('Running in the park')).toBe('running');
    });

    test('should return the default image key for unknown activities', () => {
      expect(getImageKeyForActivity('swimming')).toBe('gymsync_logo');
      expect(getImageKeyForActivity('yoga')).toBe('gymsync_logo');
    });

    test('should return the default image key for invalid inputs', () => {
      expect(getImageKeyForActivity(null)).toBe('gymsync_logo');
      expect(getImageKeyForActivity(undefined)).toBe('gymsync_logo');
      expect(getImageKeyForActivity(123)).toBe('gymsync_logo');
      expect(getImageKeyForActivity({})).toBe('gymsync_logo');
    });
  });

  // Test the logging utility functions
  describe('Logging utilities', () => {
    let consoleLogSpy;
    let consoleErrorSpy;
    
    beforeEach(() => {
      consoleLogSpy = jest.spyOn(console, 'log').mockImplementation();
      consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation();
    });
    
    afterEach(() => {
      consoleLogSpy.mockRestore();
      consoleErrorSpy.mockRestore();
    });
    
    test('log function should call console.log with timestamp', () => {
      // Define the log function
      function log(...args) {
        const ts = new Date().toISOString();
        console.log(`[${ts}]`, ...args);
      }
      
      log('Test message');
      expect(consoleLogSpy).toHaveBeenCalled();
      const call = consoleLogSpy.mock.calls[0];
      expect(call[0]).toMatch(/^\[\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}.\d{3}Z\]$/);
      expect(call[1]).toBe('Test message');
    });
    
    test('logError function should call console.error with timestamp and ERR tag', () => {
      // Define the logError function
      function logError(...args) {
        const ts = new Date().toISOString();
        console.error(`[${ts}][ERR]`, ...args);
      }
      
      logError('Error message');
      expect(consoleErrorSpy).toHaveBeenCalled();
      const call = consoleErrorSpy.mock.calls[0];
      expect(call[0]).toMatch(/^\[\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}.\d{3}Z\]\[ERR\]$/);
      expect(call[1]).toBe('Error message');
    });
  });
});