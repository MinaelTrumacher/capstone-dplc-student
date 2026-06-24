/**
 * CronJob : mise à jour du classement par groupe
 *
 * Lit les matchs de phase de groupes depuis PostgreSQL, calcule les points,
 * la différence de buts et le rang de chaque équipe, puis écrit le résultat
 * dans la table `standings` (créée si elle n'existe pas).
 *
 * Exécuté toutes les 15 min par le CronJob Kubernetes.
 */

const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT, 10) || 5432,
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
  database: process.env.DB_NAME || 'worldcup2026',
});

async function run() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Créer la table standings si elle n'existe pas
    await client.query(`
      CREATE TABLE IF NOT EXISTS standings (
        team_id       INTEGER PRIMARY KEY REFERENCES teams(id),
        team_name     VARCHAR(100) NOT NULL,
        group_letter  CHAR(1) NOT NULL,
        rank_in_group INTEGER NOT NULL DEFAULT 0,
        played        INTEGER NOT NULL DEFAULT 0,
        won           INTEGER NOT NULL DEFAULT 0,
        drawn         INTEGER NOT NULL DEFAULT 0,
        lost          INTEGER NOT NULL DEFAULT 0,
        goals_for     INTEGER NOT NULL DEFAULT 0,
        goals_against INTEGER NOT NULL DEFAULT 0,
        goal_diff     INTEGER NOT NULL DEFAULT 0,
        points        INTEGER NOT NULL DEFAULT 0,
        computed_at   TIMESTAMP DEFAULT NOW()
      )
    `);

    // Lire toutes les équipes
    const teamsResult = await client.query(
      'SELECT id, name, group_letter FROM teams ORDER BY group_letter, name'
    );

    // Lire les matchs de phase de groupes
    const matchesResult = await client.query(`
      SELECT team_home_id, team_away_id, score_home, score_away
      FROM matches
      WHERE stage = 'Group Stage'
        AND score_home IS NOT NULL
        AND score_away IS NOT NULL
    `);

    // Initialiser le classement
    const standings = {};
    for (const team of teamsResult.rows) {
      standings[team.id] = {
        team_id: team.id,
        team_name: team.name,
        group_letter: team.group_letter,
        played: 0, won: 0, drawn: 0, lost: 0,
        goals_for: 0, goals_against: 0, points: 0,
      };
    }

    // Calculer les stats depuis les matchs
    for (const match of matchesResult.rows) {
      const home = standings[match.team_home_id];
      const away = standings[match.team_away_id];
      if (!home || !away) continue;

      home.played++; away.played++;
      home.goals_for += match.score_home;
      home.goals_against += match.score_away;
      away.goals_for += match.score_away;
      away.goals_against += match.score_home;

      if (match.score_home > match.score_away) {
        home.won++; home.points += 3; away.lost++;
      } else if (match.score_home < match.score_away) {
        away.won++; away.points += 3; home.lost++;
      } else {
        home.drawn++; away.drawn++; home.points++; away.points++;
      }
    }

    // Grouper, trier et attribuer les rangs
    const groups = {};
    for (const s of Object.values(standings)) {
      if (!groups[s.group_letter]) groups[s.group_letter] = [];
      groups[s.group_letter].push(s);
    }
    for (const group of Object.values(groups)) {
      group.sort((a, b) => {
        if (b.points !== a.points) return b.points - a.points;
        const gdA = a.goals_for - a.goals_against;
        const gdB = b.goals_for - b.goals_against;
        if (gdB !== gdA) return gdB - gdA;
        return b.goals_for - a.goals_for;
      });
      group.forEach((team, idx) => { team.rank_in_group = idx + 1; });
    }

    // Upsert dans la table standings
    for (const s of Object.values(standings)) {
      const goalDiff = s.goals_for - s.goals_against;
      await client.query(`
        INSERT INTO standings
          (team_id, team_name, group_letter, rank_in_group,
           played, won, drawn, lost, goals_for, goals_against, goal_diff, points, computed_at)
        VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12, NOW())
        ON CONFLICT (team_id) DO UPDATE SET
          team_name     = EXCLUDED.team_name,
          group_letter  = EXCLUDED.group_letter,
          rank_in_group = EXCLUDED.rank_in_group,
          played        = EXCLUDED.played,
          won           = EXCLUDED.won,
          drawn         = EXCLUDED.drawn,
          lost          = EXCLUDED.lost,
          goals_for     = EXCLUDED.goals_for,
          goals_against = EXCLUDED.goals_against,
          goal_diff     = EXCLUDED.goal_diff,
          points        = EXCLUDED.points,
          computed_at   = NOW()
      `, [
        s.team_id, s.team_name, s.group_letter, s.rank_in_group,
        s.played, s.won, s.drawn, s.lost,
        s.goals_for, s.goals_against, goalDiff, s.points,
      ]);
    }

    await client.query('COMMIT');
    console.log(`[standings-job] Classement mis à jour pour ${teamsResult.rows.length} équipes.`);
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('[standings-job] Erreur :', err.message);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

run();
