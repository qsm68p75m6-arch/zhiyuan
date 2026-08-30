-- =============================================================================
-- Extend the Hunan competition dataset from a single year (2026) to three
-- years (2024-2026) so the school-detail "近三年录取" tab and any year-based
-- views have real, backend-servable rows.
--
-- Source of truth:
--   major_admission_cutoff / score_rank_mapping rows of admission_year 2026
--   whose data_kind is SIMULATED (province Hunan only; Zhejiang was removed).
--
-- Rules:
--   1. score_rank_mapping 2024/2025 curves are derived from the 2026 curve
--      with deterministic factors (0.99 / 1.02), then corrected to stay
--      non-decreasing as the score decreases. Rank resolution for users
--      always uses MAX(mapping_year) = 2026, so this never changes
--      recommendation results.
--   2. major_admission_cutoff 2024/2025 rows are derived from 2026 rows with
--      deterministic offsets of a few points, mirroring the year-over-year
--      variation already present in admission_group_cutoff.
--   3. min_rank for the new years is looked up by exact score in the extended
--      mapping. Missing mappings stay NULL; no rank is ever fabricated.
--   4. admission_cutoff (university level) is rebuilt per year as the minimum
--      major cutoff for the same university/year/province/subject, mirroring
--      init-competition-admission-cutoffs.sql.
--
-- This file is idempotent (ON DUPLICATE KEY UPDATE) and safe to re-run.
-- =============================================================================

SET NAMES utf8mb4;

START TRANSACTION;

-- -----------------------------------------------------------------------------
-- 1. 一分一段表：从 2026 曲线派生 2025 / 2024
-- -----------------------------------------------------------------------------
INSERT INTO score_rank_mapping
  (mapping_year, province, subject_type, score, rank_value, segment_count, source_url, published_date)
SELECT 2025, province, subject_type, score,
       GREATEST(1, ROUND(rank_value * 0.99)),
       CASE WHEN segment_count IS NULL THEN NULL
            ELSE GREATEST(1, ROUND(segment_count * 1.01)) END,
       source_url,
       CASE WHEN published_date IS NULL THEN NULL
            ELSE DATE_SUB(published_date, INTERVAL 1 YEAR) END
FROM score_rank_mapping
WHERE mapping_year = 2026 AND province = '湖南'
ON DUPLICATE KEY UPDATE
  rank_value = VALUES(rank_value),
  segment_count = VALUES(segment_count),
  source_url = VALUES(source_url),
  published_date = VALUES(published_date);

INSERT INTO score_rank_mapping
  (mapping_year, province, subject_type, score, rank_value, segment_count, source_url, published_date)
SELECT 2024, province, subject_type, score,
       GREATEST(1, ROUND(rank_value * 1.02)),
       CASE WHEN segment_count IS NULL THEN NULL
            ELSE GREATEST(1, ROUND(segment_count * 0.98)) END,
       source_url,
       CASE WHEN published_date IS NULL THEN NULL
            ELSE DATE_SUB(published_date, INTERVAL 2 YEAR) END
FROM score_rank_mapping
WHERE mapping_year = 2026 AND province = '湖南'
ON DUPLICATE KEY UPDATE
  rank_value = VALUES(rank_value),
  segment_count = VALUES(segment_count),
  source_url = VALUES(source_url),
  published_date = VALUES(published_date);

-- 累积位次随分数下降必须不减，对舍入造成的局部逆序做修正
UPDATE score_rank_mapping s
JOIN (
  SELECT id,
         MAX(rank_value) OVER (
           PARTITION BY province, subject_type, mapping_year
           ORDER BY score DESC
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
         ) AS floor_rank
  FROM score_rank_mapping
  WHERE mapping_year IN (2024, 2025)
) t ON t.id = s.id
SET s.rank_value = GREATEST(s.rank_value, t.floor_rank);

-- -----------------------------------------------------------------------------
-- 2. 专业线：从 2026 演示分派生 2025 / 2024
-- -----------------------------------------------------------------------------
INSERT INTO major_admission_cutoff
  (university_id, major_id, major_name, admission_year, province, subject_type,
   cutoff_score, min_rank, plan_count, duration_years, tuition_per_year,
   data_kind, calibration_source, simulation_rule, simulation_seed)
SELECT university_id, major_id, major_name, 2025, province, subject_type,
       GREATEST(0, cutoff_score + (MOD(university_id * 7 + COALESCE(major_id, 0), 11) - 5)),
       NULL,
       CASE WHEN plan_count IS NULL THEN NULL
            ELSE GREATEST(1, ROUND(plan_count * (0.9 + MOD(university_id + COALESCE(major_id, 0), 5) * 0.05))) END,
       duration_years, tuition_per_year,
       'SIMULATED',
       '湖南比赛验证专业线（2025 年演示值）：由 2026 演示分加确定性年度偏移生成，不是官方录取数据',
       'HISTORY-YEAR-V1: 2025 分 = 2026 分 + MOD(学校ID*7+专业ID,11)-5',
       CRC32(CONCAT('HISTORY-YEAR-V1:2025:', university_id, ':', COALESCE(major_id, 0), ':', subject_type))
FROM major_admission_cutoff
WHERE admission_year = 2026
  AND province = '湖南'
  AND data_kind = 'SIMULATED'
  AND cutoff_score IS NOT NULL
ON DUPLICATE KEY UPDATE
  cutoff_score = VALUES(cutoff_score),
  min_rank = VALUES(min_rank),
  plan_count = VALUES(plan_count),
  data_kind = VALUES(data_kind),
  calibration_source = VALUES(calibration_source),
  simulation_rule = VALUES(simulation_rule),
  simulation_seed = VALUES(simulation_seed);

INSERT INTO major_admission_cutoff
  (university_id, major_id, major_name, admission_year, province, subject_type,
   cutoff_score, min_rank, plan_count, duration_years, tuition_per_year,
   data_kind, calibration_source, simulation_rule, simulation_seed)
SELECT university_id, major_id, major_name, 2024, province, subject_type,
       GREATEST(0, cutoff_score + (MOD(university_id * 13 + COALESCE(major_id, 0), 13) - 6)),
       NULL,
       CASE WHEN plan_count IS NULL THEN NULL
            ELSE GREATEST(1, ROUND(plan_count * (0.88 + MOD(university_id + COALESCE(major_id, 0), 7) * 0.03))) END,
       duration_years, tuition_per_year,
       'SIMULATED',
       '湖南比赛验证专业线（2024 年演示值）：由 2026 演示分加确定性年度偏移生成，不是官方录取数据',
       'HISTORY-YEAR-V1: 2024 分 = 2026 分 + MOD(学校ID*13+专业ID,13)-6',
       CRC32(CONCAT('HISTORY-YEAR-V1:2024:', university_id, ':', COALESCE(major_id, 0), ':', subject_type))
FROM major_admission_cutoff
WHERE admission_year = 2026
  AND province = '湖南'
  AND data_kind = 'SIMULATED'
  AND cutoff_score IS NOT NULL
ON DUPLICATE KEY UPDATE
  cutoff_score = VALUES(cutoff_score),
  min_rank = VALUES(min_rank),
  plan_count = VALUES(plan_count),
  data_kind = VALUES(data_kind),
  calibration_source = VALUES(calibration_source),
  simulation_rule = VALUES(simulation_rule),
  simulation_seed = VALUES(simulation_seed);

-- 位次回填：按同口径一分一段表精确匹配
UPDATE major_admission_cutoff AS major_cutoff
LEFT JOIN score_rank_mapping AS score_rank
  ON score_rank.mapping_year = major_cutoff.admission_year
 AND score_rank.province = major_cutoff.province
 AND score_rank.subject_type = major_cutoff.subject_type
 AND score_rank.score = major_cutoff.cutoff_score
SET major_cutoff.min_rank = CASE
      WHEN score_rank.rank_value > 0 THEN score_rank.rank_value
      ELSE NULL
    END
WHERE major_cutoff.admission_year IN (2024, 2025);

-- -----------------------------------------------------------------------------
-- 3. 校线：按年取同校同科类专业线最低分重建
-- -----------------------------------------------------------------------------
INSERT INTO admission_cutoff
  (university_id, admission_year, province, subject_type, cutoff_score, min_rank)
SELECT derived.university_id,
       derived.admission_year,
       derived.province,
       derived.subject_type,
       derived.cutoff_score,
       CASE WHEN score_rank.rank_value > 0 THEN score_rank.rank_value ELSE NULL END
FROM (
  SELECT university_id, admission_year, province, subject_type, MIN(cutoff_score) AS cutoff_score
  FROM major_admission_cutoff
  WHERE admission_year IN (2024, 2025)
    AND province = '湖南'
    AND data_kind = 'SIMULATED'
    AND cutoff_score IS NOT NULL
  GROUP BY university_id, admission_year, province, subject_type
) AS derived
LEFT JOIN score_rank_mapping AS score_rank
  ON score_rank.mapping_year = derived.admission_year
 AND score_rank.province = derived.province
 AND score_rank.subject_type = derived.subject_type
 AND score_rank.score = derived.cutoff_score
ON DUPLICATE KEY UPDATE
  cutoff_score = VALUES(cutoff_score),
  min_rank = VALUES(min_rank);

COMMIT;

-- 校验概览（仅输出，不改数据）
SELECT 'score_rank_mapping' AS src, mapping_year AS yr, subject_type, COUNT(*) AS cnt
FROM score_rank_mapping GROUP BY mapping_year, subject_type
UNION ALL
SELECT 'major_admission_cutoff', admission_year, subject_type, COUNT(*)
FROM major_admission_cutoff GROUP BY admission_year, subject_type
UNION ALL
SELECT 'admission_cutoff', admission_year, subject_type, COUNT(*)
FROM admission_cutoff GROUP BY admission_year, subject_type
ORDER BY src, yr, subject_type;
