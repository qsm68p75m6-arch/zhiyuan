import { SCHOOLS, MAJORS } from "./exploreData";

/* ===== 志愿表核心：院校/专业/概率模型 + 推荐列表↔填报器桥接 ===== */

export const TOTAL = 45;
export const SEGMENTS = [
  { key: "rush", label: "冲刺志愿", range: [0, 15], cls: "rush" },
  { key: "safe", label: "稳妥志愿", range: [15, 30], cls: "safe" },
  { key: "guard", label: "保底志愿", range: [30, 45], cls: "guard" }
];

const STORE_KEY = "zhiyuan_volunteer_sheets";
const CURRENT_KEY = "zhiyuan_volunteer_current";

export function nameHash(name) {
  const s = String(name || "");
  let h = 0;
  for (let i = 0; i < s.length; i += 1) h = (h * 31 + s.charCodeAt(i)) % 9973;
  return h || 1;
}

/* 院校对象统一为 {id, name, type, province}；推荐结果里的外部院校给合成 id */
export function normalizeSchoolLike(schoolLike) {
  if (!schoolLike) return null;
  const name = schoolLike.name || schoolLike.universityName || schoolLike.schoolName || "";
  let matched = SCHOOLS.find((s) => s.name === name);
  if (matched) return matched;
  const id = schoolLike.id ?? schoolLike.schoolId ?? (1000 + nameHash(name) % 890);
  return {
    id,
    name: name || "未知院校",
    type: schoolLike.type || "综合类",
    province: schoolLike.province || schoolLike.universityProvince || "",
    synthetic: true
  };
}

// 校准线：本地库 id1≈700 → id20≈510；合成 id 由名字 hash 决定，稳定
export function calLine(schoolLike) {
  const school = normalizeSchoolLike(schoolLike);
  if (school.synthetic) return 480 + (school.id % 160);
  return 500 + (21 - school.id) * 10;
}

export function probOf(schoolLike, score) {
  const school = normalizeSchoolLike(schoolLike);
  const diff = Number(score || 0) - calLine(school);
  const micro = ((school.id * 7) % 13) - 6;
  return Math.max(8, Math.min(97, Math.round(50 + diff * 1.1 + micro)));
}

export function strategyOf(prob) {
  /* 与后端 RecommendationPolicyService 分桶对齐：35-54 冲 / 55-74 稳 / 75-100 保 */
  if (prob >= 75) return { key: "guard", label: "保" };
  if (prob >= 55) return { key: "safe", label: "稳" };
  return { key: "rush", label: "冲" };
}

/* 每所院校的备选专业（稳定伪随机：理工校偏工学），返回专业对象列表 */
export function majorDetailsOfSchool(schoolLike) {
  const school = normalizeSchoolLike(schoolLike);
  const pool = MAJORS.filter((m) => m.level === 0);
  const picked = pool.filter((m, i) => {
    const hit = ((i + 1) * 7 + school.id * 3) % 5 < 2;
    const engBias = school.type === "理工类" && m.category === "工学";
    const genBias = school.type === "综合类";
    return engBias || (hit && (genBias || m.category !== "工学"));
  });
  const list = picked.length >= 6 ? picked : pool.filter((m, i) => (i + school.id) % 4 === 0);
  return list.slice(0, 12);
}

export function majorsOfSchool(schoolLike) {
  return majorDetailsOfSchool(schoolLike).map((m) => m.name);
}

/* ===== 进行中志愿表（跨页共享、刷新不丢） ===== */
export function readCurrentSheet() {
  try {
    const raw = JSON.parse(localStorage.getItem(CURRENT_KEY) || "null");
    if (!Array.isArray(raw) || raw.length !== TOTAL) return null;
    return raw;
  } catch {
    return null;
  }
}

export function writeCurrentSheet(slots) {
  try {
    localStorage.setItem(CURRENT_KEY, JSON.stringify(slots));
  } catch {
    /* ignore */
  }
}

export function clearCurrentSheet() {
  localStorage.removeItem(CURRENT_KEY);
}

/* 投放一个志愿到对应段第一个空位；段满则落到全局第一个空位 */
export function appendToCurrentSheet(slot, strategyKey) {
  const segKey = strategyKey === "guarantee" ? "guard" : strategyKey;
  const seg = SEGMENTS.find((s) => s.key === segKey) || SEGMENTS[1];
  const current = readCurrentSheet() || Array.from({ length: TOTAL }, () => null);
  for (let i = seg.range[0]; i < seg.range[1]; i += 1) {
    if (!current[i]) {
      current[i] = slot;
      writeCurrentSheet(current);
      return { ok: true, position: i + 1, segLabel: seg.label };
    }
  }
  for (let i = 0; i < TOTAL; i += 1) {
    if (!current[i]) {
      current[i] = slot;
      writeCurrentSheet(current);
      return { ok: true, position: i + 1, segLabel: "其他空位", fallback: true };
    }
  }
  return { ok: false, message: "志愿表已满，请先清理志愿位" };
}

export function currentSheetCount() {
  const cur = readCurrentSheet();
  return cur ? cur.filter(Boolean).length : 0;
}

export { STORE_KEY };
