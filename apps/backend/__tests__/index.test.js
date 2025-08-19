const request = require('supertest');

// Mock environment variables before importing the app
process.env.API_KEY = 'test-key';

// Import the actual app and statusMap
const { app, statusMap } = require('../index.js');

// Tests
describe('GymSync Backend API', () => {
  beforeEach(() => {
    // Clear the status map before each test
    statusMap.clear();
  });

  test('GET / should return a welcome message', async () => {
    const response = await request(app).get('/');
    expect(response.status).toBe(200);
    expect(response.text).toBe('✅ GymSync Backend is running!');
  });

  test('POST /api/v1/status should create a new status', async () => {
    const response = await request(app)
      .post('/api/v1/status')
      .set('Authorization', 'Bearer test-key')
      .send({
        discord_id: '123456789',
        status: {
          activity: 'running'
        }
      });
    
    expect(response.status).toBe(200);
    expect(response.body).toEqual({ ok: true });
    
    // Verify the status was created
    const statusResponse = await request(app).get('/api/v1/status/123456789');
    expect(statusResponse.status).toBe(200);
    expect(statusResponse.body.activity).toBe('running');
    expect(statusResponse.body.paused).toBe(false);
  });

  test('POST /api/v1/status should return 401 with invalid API key', async () => {
    const response = await request(app)
      .post('/api/v1/status')
      .set('Authorization', 'Bearer invalid-key')
      .send({
        discord_id: '123456789',
        status: {
          activity: 'running'
        }
      });
    
    expect(response.status).toBe(401);
    expect(response.body).toEqual({ error: 'Unauthorized' });
  });

  test('POST /api/v1/status should return 400 with invalid payload', async () => {
    const response = await request(app)
      .post('/api/v1/status')
      .set('Authorization', 'Bearer test-key')
      .send({
        discord_id: '123456789',
        // Missing status
      });
    
    expect(response.status).toBe(400);
    expect(response.body).toEqual({ error: 'Invalid payload' });
  });

  test('POST /api/v1/status/pause should pause an activity', async () => {
    // First create a status
    await request(app)
      .post('/api/v1/status')
      .set('Authorization', 'Bearer test-key')
      .send({
        discord_id: '123456789',
        status: {
          activity: 'running'
        }
      });
    
    // Then pause it
    const response = await request(app)
      .post('/api/v1/status/pause')
      .set('Authorization', 'Bearer test-key')
      .send({
        discord_id: '123456789'
      });
    
    expect(response.status).toBe(200);
    expect(response.body).toEqual({ ok: true });
    
    // Verify the status was paused
    const statusResponse = await request(app).get('/api/v1/status/123456789');
    expect(statusResponse.status).toBe(200);
    expect(statusResponse.body.activity).toBe('running');
    expect(statusResponse.body.paused).toBe(true);
  });

  test('POST /api/v1/status/resume should resume a paused activity', async () => {
    // First create a status
    await request(app)
      .post('/api/v1/status')
      .set('Authorization', 'Bearer test-key')
      .send({
        discord_id: '123456789',
        status: {
          activity: 'running'
        }
      });
    
    // Then pause it
    await request(app)
      .post('/api/v1/status/pause')
      .set('Authorization', 'Bearer test-key')
      .send({
        discord_id: '123456789'
      });
    
    // Then resume it
    const response = await request(app)
      .post('/api/v1/status/resume')
      .set('Authorization', 'Bearer test-key')
      .send({
        discord_id: '123456789'
      });
    
    expect(response.status).toBe(200);
    expect(response.body).toEqual({ ok: true });
    
    // Verify the status was resumed
    const statusResponse = await request(app).get('/api/v1/status/123456789');
    expect(statusResponse.status).toBe(200);
    expect(statusResponse.body.activity).toBe('running');
    expect(statusResponse.body.paused).toBe(false);
  });

  test('POST /api/v1/status/stop should remove a status', async () => {
    // First create a status
    await request(app)
      .post('/api/v1/status')
      .set('Authorization', 'Bearer test-key')
      .send({
        discord_id: '123456789',
        status: {
          activity: 'running'
        }
      });
    
    // Then stop it
    const response = await request(app)
      .post('/api/v1/status/stop')
      .set('Authorization', 'Bearer test-key')
      .send({
        discord_id: '123456789'
      });
    
    expect(response.status).toBe(200);
    expect(response.body).toEqual({ ok: true });
    
    // Verify the status was removed
    const statusResponse = await request(app).get('/api/v1/status/123456789');
    expect(statusResponse.status).toBe(404);
    expect(statusResponse.body).toEqual({ error: 'Not found' });
  });

  test('GET /api/v1/status/:discord_id should return 404 for non-existent status', async () => {
    const response = await request(app).get('/api/v1/status/non-existent');
    expect(response.status).toBe(404);
    expect(response.body).toEqual({ error: 'Not found' });
  });
});