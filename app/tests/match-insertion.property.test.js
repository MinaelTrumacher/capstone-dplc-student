/**
 * Property-Based Test: Round-trip d'insertion de match
 *
 * Feature: capstone-cloud-resilience, Property 1: Round-trip d'insertion de match
 * Validates: Requirements 4.1
 *
 * For any valid JSON body containing a non-empty team_home, non-empty team_away,
 * score_home >= 0, score_away >= 0, a stage among accepted values, and an ISO date,
 * POST /api/data must return HTTP 201 with an id, and the inserted data must match
 * the input values.
 */

const fc = require('fast-check');
const request = require('supertest');

// Mock pg before requiring the app
jest.mock('pg', () => {
  const mockQuery = jest.fn();
  const mockPool = { query: mockQuery };
  return { Pool: jest.fn(() => mockPool) };
});

const { app, pool } = require('../main');

const validStages = ['Group Stage', 'Round of 16', 'Quarter-final', 'Semi-final', 'Final'];

describe('Feature: capstone-cloud-resilience, Property 1: Round-trip d\'insertion de match', () => {
  let insertedData;

  beforeEach(() => {
    insertedData = null;
    pool.query.mockReset();
  });

  afterAll(() => {
    jest.restoreAllMocks();
  });

  it('should return HTTP 201 with an id and inserted data matches input for any valid match data', async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.record({
          team_home: fc.string({ minLength: 1 }).filter(s => s.trim().length > 0),
          team_away: fc.string({ minLength: 1 }).filter(s => s.trim().length > 0),
          score_home: fc.nat(),
          score_away: fc.nat(),
          stage: fc.constantFrom(...validStages),
          date: fc.date({
            min: new Date('2000-01-01'),
            max: new Date('2099-12-31'),
          }),
        }).filter(data => data.team_home.trim() !== data.team_away.trim()),
        async (matchData) => {
          const dateStr = matchData.date.toISOString().split('T')[0];
          let capturedInsertParams = null;

          // Mock pool.query to simulate DB behavior:
          // 1st call: SELECT id FROM teams WHERE name = $1 (team_home) -> returns {id: 1}
          // 2nd call: SELECT id FROM teams WHERE name = $1 (team_away) -> returns {id: 2}
          // 3rd call: INSERT INTO matches ... RETURNING id -> returns {id: 42}
          pool.query.mockImplementation((sql, params) => {
            if (sql.includes('SELECT id FROM teams WHERE name')) {
              // Return a valid team id for any team name lookup
              if (params[0] === matchData.team_home.trim()) {
                return Promise.resolve({ rows: [{ id: 1 }] });
              }
              if (params[0] === matchData.team_away.trim()) {
                return Promise.resolve({ rows: [{ id: 2 }] });
              }
              return Promise.resolve({ rows: [] });
            }
            if (sql.includes('INSERT INTO matches')) {
              capturedInsertParams = params;
              return Promise.resolve({ rows: [{ id: 42 }] });
            }
            return Promise.resolve({ rows: [] });
          });

          const payload = {
            team_home: matchData.team_home,
            team_away: matchData.team_away,
            score_home: matchData.score_home,
            score_away: matchData.score_away,
            stage: matchData.stage,
            date: dateStr,
          };

          const res = await request(app)
            .post('/api/data')
            .set('Content-Type', 'application/json')
            .send(payload);

          // Property assertions:
          // 1. Response status is 201
          expect(res.status).toBe(201);

          // 2. Response body contains an id field
          expect(res.body).toHaveProperty('id');
          expect(res.body.id).toBe(42);

          // 3. The data that would be inserted matches the input data
          expect(capturedInsertParams).not.toBeNull();
          // capturedInsertParams = [teamHomeId, teamAwayId, score_home, score_away, stage, date]
          expect(capturedInsertParams[0]).toBe(1); // team_home_id
          expect(capturedInsertParams[1]).toBe(2); // team_away_id
          expect(capturedInsertParams[2]).toBe(matchData.score_home);
          expect(capturedInsertParams[3]).toBe(matchData.score_away);
          expect(capturedInsertParams[4]).toBe(matchData.stage);
          expect(capturedInsertParams[5]).toBe(dateStr);
        }
      ),
      { numRuns: 100 }
    );
  });
});
