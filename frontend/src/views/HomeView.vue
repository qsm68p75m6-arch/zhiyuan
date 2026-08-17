<script setup>
import { Calendar, ChatDotRound, Clock, Collection, DataLine, EditPen, MagicStick, OfficeBuilding, Promotion, Trophy } from "@element-plus/icons-vue";
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue";
import { useRouter } from "vue-router";
import GkHeader from "../components/GkHeader.vue";
import GkSchoolLogo from "../components/GkSchoolLogo.vue";
import { MAJORS, SCHOOLS, VOLUNTEER_SCHOOL_TOP } from "../utils/exploreData";
import { NEWS_TAGS, newsById } from "../utils/newsData";
import { readStoredAuth } from "../utils/recommendation";

const router = useRouter();

/* ── 轮播 Banner ── */
const SLIDES = [
  {
    kicker: "2026 届智能报考季",
    title: "我向往的大学",
    desc: "AI 智能填报 · 一分都不浪费，基于分数、位次与选科生成「冲稳保」梯度志愿方案",
    primaryText: "开始智能推荐",
    ghostText: "问小智",
    primaryTo: { path: "/agent", query: { q: "帮我基于分数、位次和选科，生成冲稳保梯度志愿方案" } },
    ghostTo: { path: "/agent" }
  },
  {
    kicker: "模拟报志愿",
    title: "冲稳保 · 三档智能定位",
    desc: "输入分数与选科，即刻测算可冲击、较稳妥、可保底的院校数量与位次区间",
    primaryText: "去模拟报志愿",
    ghostText: "问小智",
    primaryTo: { name: "recommend" },
    ghostTo: { path: "/agent" }
  },
  {
    kicker: "AI 报考助手在线",
    title: "问小智 · 有问必答",
    desc: "分数能上哪些大学？专业怎么选？志愿怎么填？AI 在线答疑，随时帮你分析",
    primaryText: "立即提问",
    ghostText: "了解智能推荐",
    primaryTo: { path: "/agent" },
    ghostTo: { name: "recommend" }
  }
];
const slideIndex = ref(0);
let slideTimer = null;

onMounted(() => {
  slideTimer = window.setInterval(() => {
    slideIndex.value = (slideIndex.value + 1) % SLIDES.length;
  }, 5000);
});
onBeforeUnmount(() => window.clearInterval(slideTimer));

/* ── 模拟报志愿面板 ── */
const storedAuth = readStoredAuth();
const simSubject = ref(storedAuth?.user?.subjectType === "HISTORY" ? "历史" : "物理");
const simPicks = ref([]);
const SIM_SECONDS = ["化学", "生物", "政治", "地理"];
const simScore = ref(storedAuth?.user?.score ?? "");

function togglePick(item) {
  const idx = simPicks.value.indexOf(item);
  if (idx >= 0) {
    simPicks.value.splice(idx, 1);
  } else if (simPicks.value.length < 2) {
    simPicks.value.push(item);
  }
}

const simStats = computed(() => {
  const score = Number(simScore.value);
  if (!score || Number.isNaN(score) || score < 100 || score > 750) return null;
  const rank = Math.max(66, Math.round(780000 * Math.pow(1 - score / 760, 1.6)));
  const pct = Math.min(99, Math.max(3, Math.round(100 - (rank / 520000) * 100)));
  return {
    score,
    rank,
    rankLow: Math.round(rank * 0.982),
    rankHigh: Math.round(rank * 1.003),
    pct,
    rush: Math.max(9, Math.round((score - 400) * 1.5)),
    safe: Math.max(28, Math.round((score - 380) * 2.4)),
    guarantee: Math.max(52, Math.round((score - 360) * 3.2))
  };
});

function goSimRecommend() {
  router.push({ name: "recommend" });
}

/* ── 快捷入口 ── */
const QUICK_ENTRIES = [
  { label: "查大学", to: "/schools", icon: OfficeBuilding, color: "#3b82f6", bg: "#e8f1fe" },
  { label: "查专业", to: "/majors", icon: Collection, color: "#10b981", bg: "#e6f8f1" },
  { label: "志愿填报", to: "/volunteer", icon: EditPen, color: "#ff6600", bg: "#fff0e5" },
  { label: "智能选大学", to: "/choose", icon: MagicStick, color: "#8b5cf6", bg: "#f1ecfe" },
  { label: "院校排行", to: "/rank", icon: Trophy, color: "#f59e0b", bg: "#fdf3e0" },
  { label: "一分一段", to: "/segments", icon: DataLine, color: "#06b6d4", bg: "#e3f8fb" },
  { label: "招生计划", to: "/enroll", icon: Calendar, color: "#ec4899", bg: "#fdeaf4" }
];

/* ── 热点资讯 + 快捷卡片（真实资讯源：中国教育在线 gaokao.eol.cn，站内详情页） ── */
const NEWS_ROW_IDS = [2764667, 2764248, 2764252, 2763565, 2763535, 2762894, 2762544, 2762535];
const NEWS_ROWS = NEWS_ROW_IDS.map((id) => newsById(id)).filter(Boolean);
const newsHeadline = NEWS_ROWS[0];
const newsSub = NEWS_ROWS.slice(1, 5);

const TILES = [
  { title: "智能选大学", desc: "分数选科 · 定位院校", to: "/choose", icon: MagicStick, color: "#8b5cf6", bg: "#f1ecfe" },
  { title: "模拟志愿表", desc: "45 个志愿槽在线填", to: "/volunteer", icon: EditPen, color: "#ff6600", bg: "#fff0e5" },
  { title: "问小智 AI", desc: "报考问题 · 有问必答", to: "/agent", icon: ChatDotRound, color: "#3b82f6", bg: "#e8f1fe" },
  { title: "历史记录", desc: "推荐对话 · 一键回看", to: "/history", icon: Clock, color: "#10b981", bg: "#e6f8f1" }
];

/* ── 热门院校 ── */
const SCHOOL_TABS = ["全部", "综合类", "理工类"];
const schoolTab = ref("全部");
const schoolOffset = ref(0);
const hotSchools = computed(() => {
  const list = schoolTab.value === "全部" ? SCHOOLS : SCHOOLS.filter((s) => s.type === schoolTab.value);
  const take = Math.min(8, list.length);
  const out = [];
  for (let i = 0; i < take; i += 1) {
    out.push(list[(schoolOffset.value + i) % list.length]);
  }
  return out;
});
watch(schoolTab, () => {
  schoolOffset.value = 0;
});

function shuffleSchools() {
  schoolOffset.value += 8;
}

/* ── 热门专业 ── */
const MAJOR_LEVEL_TABS = ["本科", "专科"];
const majorLevelTab = ref("本科");
const CATEGORY_COLORS = {
  工学: ["#3b82f6", "#e8f1fe"],
  理学: ["#06b6d4", "#e3f8fb"],
  医学: ["#10b981", "#e6f8f1"],
  文学: ["#ec4899", "#fdeaf4"],
  经济学: ["#f59e0b", "#fdf3e0"],
  法学: ["#ff6600", "#fff0e5"],
  管理学: ["#8b5cf6", "#f1ecfe"],
  default: ["#6b7280", "#f3f4f6"]
};
const hotMajors = computed(() => {
  const level = majorLevelTab.value === "本科" ? 0 : 1;
  return [...MAJORS]
    .filter((m) => m.level === level)
    .sort((a, b) => (a.hot || 999) - (b.hot || 999))
    .slice(0, 5);
});

/* ── 报考专题 ── */
const TOPICS = [
  { label: "志愿填报", to: "/volunteer", icon: EditPen, color: "#3b82f6", bg: "#e8f1fe" },
  { label: "招生计划", to: "/enroll", icon: Calendar, color: "#10b981", bg: "#e6f8f1" },
  { label: "一分一段", to: "/segments", icon: DataLine, color: "#06b6d4", bg: "#e3f8fb" },
  { label: "院校排行", to: "/rank", icon: Trophy, color: "#f59e0b", bg: "#fdf3e0" },
  { label: "智能选大学", to: "/choose", icon: MagicStick, color: "#8b5cf6", bg: "#f1ecfe" },
  { label: "查大学", to: "/schools", icon: OfficeBuilding, color: "#ff6600", bg: "#fff0e5" },
  { label: "查专业", to: "/majors", icon: Collection, color: "#ec4899", bg: "#fdeaf4" },
  { label: "AI 对话", to: "/agent", icon: ChatDotRound, color: "#3b82f6", bg: "#e8f1fe" },
  { label: "志愿方案", to: "/plans", icon: Clock, color: "#10b981", bg: "#e6f8f1" }
];

/* ── 高考资讯流 ── */
const NEWS_TABS = NEWS_TAGS;
const newsTab = ref("全部");
const filteredNews = computed(() => {
  if (newsTab.value === "全部") return NEWS_ROWS.slice(0, 6);
  return NEWS_ROWS.filter((item) => item.tag === newsTab.value);
});

/* ── 院校热度 ── */
const heatList = VOLUNTEER_SCHOOL_TOP.slice(0, 5).map((item, i) => {
  const school = SCHOOLS.find((s) => s.name === item.name);
  return { ...item, id: school?.id, hot: (9.9 - i * 0.86).toFixed(1) };
});
</script>

<template>
  <div class="gk-page">
    <GkHeader active="首页" />

    <main class="gk-home__container gk-hp">
      <!-- ① 轮播 Banner + 模拟报志愿 -->
      <section class="gk-hp__hero">
        <div class="gk-hp__banner">
          <div
            v-for="(slide, i) in SLIDES"
            :key="slide.title"
            class="gk-hp__slide"
            :class="{ 'is-active': i === slideIndex }"
          >
            <p class="gk-hp__slide-kicker">{{ slide.kicker }}</p>
            <h2 class="gk-hp__slide-title">{{ slide.title }}</h2>
            <p class="gk-hp__slide-desc">{{ slide.desc }}</p>
            <div class="gk-hp__slide-actions">
              <button class="gk-hp__slide-primary" type="button" @click="router.push(slide.primaryTo)">{{ slide.primaryText }}</button>
              <button class="gk-hp__slide-ghost" type="button" @click="router.push(slide.ghostTo)">
                <el-icon><Promotion /></el-icon>
                {{ slide.ghostText }}
              </button>
            </div>
          </div>
          <div class="gk-hp__slide-dots">
            <button
              v-for="(slide, i) in SLIDES"
              :key="`dot-${slide.title}`"
              type="button"
              :class="{ 'is-active': i === slideIndex }"
              :aria-label="`第${i + 1}张`"
              @click="slideIndex = i"
            />
          </div>
        </div>

        <aside class="gk-hp__sim">
          <header class="gk-hp__sim-head">
            <h3>模拟报志愿</h3>
            <div class="gk-hp__sim-types">
              <span class="is-active">普通类</span>
              <span>艺术类</span>
            </div>
          </header>

          <div class="gk-hp__sim-field">
            <span class="gk-hp__sim-label">首选科目</span>
            <div class="gk-hp__sim-opts">
              <button type="button" :class="{ 'is-active': simSubject === '物理' }" @click="simSubject = '物理'">物理</button>
              <button type="button" :class="{ 'is-active': simSubject === '历史' }" @click="simSubject = '历史'">历史</button>
            </div>
          </div>

          <div class="gk-hp__sim-field">
            <span class="gk-hp__sim-label">再选科目 <em>（最多 2 门）</em></span>
            <div class="gk-hp__sim-opts gk-hp__sim-opts--four">
              <button
                v-for="item in SIM_SECONDS"
                :key="item"
                type="button"
                :class="{ 'is-active': simPicks.includes(item) }"
                @click="togglePick(item)"
              >
                {{ item }}
              </button>
            </div>
          </div>

          <div class="gk-hp__sim-field">
            <span class="gk-hp__sim-label">分数</span>
            <input v-model.trim="simScore" class="gk-hp__sim-input" type="number" min="100" max="750" placeholder="输入高考分数" />
          </div>

          <div v-if="simStats" class="gk-hp__sim-chart">
            <div class="gk-hp__sim-chart-top">
              <strong>{{ simStats.score }}<i>分</i></strong>
              <span>约 {{ simStats.rankLow.toLocaleString() }}–{{ simStats.rankHigh.toLocaleString() }} 名</span>
            </div>
            <div class="gk-hp__sim-bar">
              <div :style="{ width: `${simStats.pct}%` }" />
            </div>
            <p>超过本省 {{ simStats.pct }}% 考生</p>
          </div>
          <div v-else class="gk-hp__sim-chart gk-hp__sim-chart--empty">
            <p>输入分数后，自动测算位次区间与推荐院校数量</p>
          </div>

          <div class="gk-hp__sim-stats">
            <div><strong>{{ simStats ? simStats.rush : "—" }}</strong><span>可冲击</span></div>
            <div><strong>{{ simStats ? simStats.safe : "—" }}</strong><span>较稳妥</span></div>
            <div><strong>{{ simStats ? simStats.guarantee : "—" }}</strong><span>可保底</span></div>
          </div>

          <button class="gk-hp__sim-cta" type="button" @click="goSimRecommend">智能推荐大学</button>
        </aside>
      </section>

      <!-- ② 快捷入口 -->
      <nav class="gk-hp__quick" aria-label="快捷入口">
        <button v-for="entry in QUICK_ENTRIES" :key="entry.label" type="button" @click="router.push(entry.to)">
          <span class="gk-hp__quick-icon" :style="{ color: entry.color, background: entry.bg }">
            <el-icon><component :is="entry.icon" /></el-icon>
          </span>
          <span>{{ entry.label }}</span>
        </button>
      </nav>

      <!-- ③ 热点资讯 + 快捷卡片 -->
      <section class="gk-hp__row">
        <div class="gk-hp__card">
          <header class="gk-hp__card-head">
            <h3>热点资讯 <i>HOT</i></h3>
          </header>
          <router-link
            class="gk-hp__news-headline"
            :to="`/news/${newsHeadline.id}`"
            :title="newsHeadline.title"
          >
            <em>{{ newsHeadline.tag }}</em>
            <strong>{{ newsHeadline.title }}</strong>
            <span>{{ newsHeadline.source }} · {{ newsHeadline.date }}</span>
          </router-link>
          <ul class="gk-hp__news-sub">
            <li v-for="item in newsSub" :key="item.id">
              <router-link :to="`/news/${item.id}`" :title="item.title">
                <i />{{ item.title }}
                <span>{{ item.date }}</span>
              </router-link>
            </li>
          </ul>
        </div>

        <aside class="gk-hp__tiles">
          <button v-for="tile in TILES" :key="tile.title" type="button" class="gk-hp__tile" @click="router.push(tile.to)">
            <span class="gk-hp__tile-icon" :style="{ color: tile.color, background: tile.bg }">
              <el-icon><component :is="tile.icon" /></el-icon>
            </span>
            <span class="gk-hp__tile-copy">
              <strong>{{ tile.title }}</strong>
              <em>{{ tile.desc }}</em>
            </span>
            <span class="gk-hp__tile-more">点击进入 &gt;</span>
          </button>
        </aside>
      </section>

      <!-- ④ 热门院校 -->
      <section class="gk-hp__card gk-hp__schools">
        <header class="gk-hp__card-head">
          <h3>热门院校</h3>
          <div class="gk-hp__head-right">
            <div class="gk-hp__seg">
              <button
                v-for="tab in SCHOOL_TABS"
                :key="tab"
                type="button"
                :class="{ 'is-active': schoolTab === tab }"
                @click="schoolTab = tab"
              >
                {{ tab }}
              </button>
            </div>
            <button class="gk-hp__shuffle" type="button" @click="shuffleSchools">
              <el-icon><Promotion /></el-icon>
              换一换
            </button>
          </div>
        </header>
        <div class="gk-hp__school-grid">
          <button v-for="school in hotSchools" :key="`${school.id}-${school.name}`" type="button" class="gk-hp__school" @click="router.push('/schools')">
            <GkSchoolLogo :school="school" />
            <span class="gk-hp__school-copy">
              <strong>{{ school.name }}</strong>
              <em>{{ school.type }} · {{ school.nature }}</em>
            </span>
            <span class="gk-hp__school-more">查看院校 &gt;</span>
          </button>
        </div>
      </section>

      <!-- ⑤ 热门专业 + 报考专题 -->
      <section class="gk-hp__row">
        <div class="gk-hp__card">
          <header class="gk-hp__card-head">
            <h3>热门专业</h3>
            <div class="gk-hp__head-right">
              <div class="gk-hp__seg">
                <button
                  v-for="tab in MAJOR_LEVEL_TABS"
                  :key="tab"
                  type="button"
                  :class="{ 'is-active': majorLevelTab === tab }"
                  @click="majorLevelTab = tab"
                >
                  {{ tab }}
                </button>
              </div>
              <span class="gk-hp__more" @click="router.push('/majors')">更多 &gt;</span>
            </div>
          </header>
          <ul class="gk-hp__majors">
            <li v-for="major in hotMajors" :key="major.code">
              <button type="button" @click="router.push(`/majors/${major.code}`)">
                <span
                  class="gk-hp__major-badge"
                  :style="{ color: (CATEGORY_COLORS[major.category] || CATEGORY_COLORS.default)[0], background: (CATEGORY_COLORS[major.category] || CATEGORY_COLORS.default)[1] }"
                >
                  {{ major.name.slice(0, 1) }}
                </span>
                <span class="gk-hp__major-copy">
                  <strong>{{ major.name }}</strong>
                  <em>{{ major.category }} · {{ major.duration }} · 毕业年薪 {{ major.salary }}</em>
                </span>
                <span class="gk-hp__major-count">{{ major.schoolCount }} 所院校开设</span>
              </button>
            </li>
          </ul>
        </div>

        <aside class="gk-hp__card gk-hp__topics">
          <header class="gk-hp__card-head">
            <h3>报考专题</h3>
            <span class="gk-hp__more" @click="router.push('/volunteer')">更多 &gt;</span>
          </header>
          <div class="gk-hp__topic-grid">
            <button v-for="topic in TOPICS" :key="topic.label" type="button" @click="router.push(topic.to)">
              <span class="gk-hp__topic-icon" :style="{ color: topic.color, background: topic.bg }">
                <el-icon><component :is="topic.icon" /></el-icon>
              </span>
              <span class="gk-hp__topic-label">{{ topic.label }}</span>
              <span class="gk-hp__topic-more">查看详情 &gt;</span>
            </button>
          </div>
        </aside>
      </section>

      <!-- ⑥ 高考资讯 + 院校热度 -->
      <section class="gk-hp__row gk-hp__row--last">
        <div class="gk-hp__card">
          <header class="gk-hp__card-head">
            <h3>高考资讯</h3>
          </header>
          <div class="gk-hp__news-tabs">
            <button
              v-for="tab in NEWS_TABS"
              :key="tab"
              type="button"
              :class="{ 'is-active': newsTab === tab }"
              @click="newsTab = tab"
            >
              {{ tab }}
            </button>
          </div>
          <ul class="gk-hp__news-feed">
            <li v-for="item in filteredNews" :key="item.id">
              <router-link :to="`/news/${item.id}`" :title="item.title">
                <em>{{ item.tag }}</em>
                <span class="gk-hp__feed-title">{{ item.title }}</span>
                <span class="gk-hp__feed-date">{{ item.date }}</span>
              </router-link>
            </li>
          </ul>
        </div>

        <aside class="gk-hp__card gk-hp__heat">
          <header class="gk-hp__card-head">
            <h3>院校热度</h3>
            <span class="gk-hp__more" @click="router.push('/rank')">更多 &gt;</span>
          </header>
          <div class="gk-hp__seg gk-hp__seg--compact">
            <button type="button" class="is-active">本科</button>
            <button type="button">专科</button>
          </div>
          <ol class="gk-hp__heat-list">
            <li v-for="(item, i) in heatList" :key="item.name">
              <span class="gk-hp__heat-no" :class="`gk-hp__heat-no--${i < 3 ? 'top' : 'rest'}`">{{ i + 1 }}</span>
              <GkSchoolLogo v-if="item.id" :school="{ id: item.id, name: item.name }" size="mini" />
              <span class="gk-hp__heat-name">{{ item.name }}</span>
              <span class="gk-hp__heat-val"><i /><b>{{ item.hot }}w</b></span>
            </li>
          </ol>
        </aside>
      </section>
    </main>

    <footer class="gk-hp__footer">
      <div class="gk-home__container">
        <p>智愿AI报考平台 · 2026 智能报考季 · 数据仅供志愿填报参考</p>
      </div>
    </footer>
  </div>
</template>
