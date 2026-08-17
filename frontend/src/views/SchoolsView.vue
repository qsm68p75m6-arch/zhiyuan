<script setup>
import { ArrowDown, Search } from "@element-plus/icons-vue";
import { computed, ref } from "vue";
import { useRouter } from "vue-router";
import GkHeader from "../components/GkHeader.vue";
import GkSchoolLogo from "../components/GkSchoolLogo.vue";
import GkSidePanel from "../components/GkSidePanel.vue";
import { SCHOOLS, schoolLoc, schoolTags } from "../utils/exploreData";
import hotIcon from "../assets/gk_hot.png";
import searchIcon from "../assets/gk_search_icon.png";

const router = useRouter();

/* 与掌上高考 /school/search 一致的筛选项（军校-国际本科快捷栏已按需求舍弃） */
const PROVINCE_OPTS = ["不限", ...Array.from(new Set(SCHOOLS.map((s) => s.province)))];
const TYPE_OPTS = ["不限", "综合", "理工", "师范", "农林", "医药", "财经", "政法", "语言", "艺术", "体育", "民族"];
const NATURE_OPTS = ["不限", "公办", "民办", "中外合作办学"];
const FEATURE_OPTS = ["不限", "985", "211", "双一流", "强基", "研究生院"];
const SORT_OPTS = ["默认排序", "分数由高到低", "分数由低到高", "搜索热度由高到低", "保研率由高到低"];

/* 专业大类 → 院校类型映射（数据为院校维度，按类型近似筛选） */
const MAJOR_TYPE_MAP = {
  "计算机类": "理工", "电子信息类": "理工", "机械类": "理工", "电气类": "理工", "材料类": "理工",
  "土木类": "理工", "自动化类": "理工", "航空航天类": "理工", "法学类": "政法", "政治学类": "政法",
  "教育学类": "师范", "中国语言文学类": "语言", "外国语言文学类": "语言", "经济学类": "财经",
  "金融学类": "财经", "工商管理类": "财经", "临床医学类": "医药", "基础医学类": "医药", "药学类": "医药",
  "植物生产类": "农林", "动物医学类": "农林", "设计学类": "艺术", "音乐与舞蹈学类": "艺术", "体育学类": "体育"
};
const MAJOR_OPTS = ["不限", ...Object.keys(MAJOR_TYPE_MAP)];

const provinceFilter = ref("不限");
const typeFilter = ref("不限");
const natureFilter = ref("不限");
const featureFilter = ref("不限");
const majorFilter = ref("不限");
const sortKey = ref("默认排序");
const keyword = ref("");

const FEATURE_FIELD = { "985": "is985", "211": "is211", "双一流": "isDoubleFirstClass" };

function minScoreOf(school) {
  return 698 - school.id * 3 - (school.id % 5);
}
function probabilityOf(school) {
  return 42 + ((school.id * 37) % 52);
}
function probLevelOf(value) {
  if (value >= 75) return "保";
  if (value >= 55) return "稳";
  return "冲";
}
function isHot(school) {
  return school.id <= 8;
}
function baoyanOf(school) {
  return 18 + ((school.id * 13) % 38);
}

const filtered = computed(() => {
  const kw = keyword.value.trim();
  const list = SCHOOLS.filter((school) => {
    if (provinceFilter.value !== "不限" && school.province !== provinceFilter.value) return false;
    if (typeFilter.value !== "不限" && !school.type.startsWith(typeFilter.value)) return false;
    if (natureFilter.value !== "不限" && school.nature !== natureFilter.value) return false;
    if (featureFilter.value !== "不限") {
      const field = FEATURE_FIELD[featureFilter.value];
      if (field && !school[field]) return false;
    }
    if (majorFilter.value !== "不限" && !school.type.startsWith(MAJOR_TYPE_MAP[majorFilter.value] || "")) return false;
    if (kw && !school.name.includes(kw)) return false;
    return true;
  });
  const sorted = [...list];
  if (sortKey.value === "分数由高到低") sorted.sort((a, b) => minScoreOf(b) - minScoreOf(a));
  else if (sortKey.value === "分数由低到低" || sortKey.value === "分数由低到高") sorted.sort((a, b) => minScoreOf(a) - minScoreOf(b));
  else if (sortKey.value === "搜索热度由高到低") sorted.sort((a, b) => a.id - b.id);
  else if (sortKey.value === "保研率由高到低") sorted.sort((a, b) => baoyanOf(b) - baoyanOf(a));
  return sorted;
});

function applyType(value) {
  typeFilter.value = value;
  natureFilter.value = "不限";
  featureFilter.value = "不限";
}

function askAdmission(school) {
  router.push({ path: "/agent", query: { q: `我的分数能上${school.name}吗？帮我分析录取概率` } });
}
</script>

<template>
  <div class="gk-page">
    <GkHeader active="查大学" />

    <main class="gk-home__container gk-page__main">
      <div class="gk-page__body">
        <section class="gk-page__content">
          <div class="gks-card">
            <div class="gks-search">
              <el-dropdown trigger="click" popper-class="gks-drop">
                <button type="button" class="gks-select">
                  <span :class="{ 'is-set': provinceFilter !== '不限' }">{{ provinceFilter === "不限" ? "位置" : provinceFilter }}</span>
                  <el-icon><ArrowDown /></el-icon>
                </button>
                <template #dropdown>
                  <div class="gks-drop__grid">
                    <button v-for="p in PROVINCE_OPTS" :key="p" type="button" :class="['gks-drop__opt', { 'is-active': provinceFilter === p }]" @click="provinceFilter = p">{{ p }}</button>
                  </div>
                </template>
              </el-dropdown>

              <el-dropdown trigger="click" popper-class="gks-drop gks-drop--wide">
                <button type="button" class="gks-select">
                  <span :class="{ 'is-set': typeFilter !== '不限' || natureFilter !== '不限' || featureFilter !== '不限' }">
                    {{ typeFilter !== "不限" || natureFilter !== "不限" || featureFilter !== "不限" ? [typeFilter, natureFilter, featureFilter].filter((v) => v !== "不限").join("/") : "类型" }}
                  </span>
                  <el-icon><ArrowDown /></el-icon>
                </button>
                <template #dropdown>
                  <div class="gks-drop__groups">
                    <div class="gks-drop__group">
                      <p class="gks-drop__label">院校类型</p>
                      <div class="gks-drop__grid">
                        <button v-for="t in TYPE_OPTS" :key="t" type="button" :class="['gks-drop__opt', { 'is-active': typeFilter === t }]" @click="applyType(t)">{{ t }}</button>
                      </div>
                    </div>
                    <div class="gks-drop__group">
                      <p class="gks-drop__label">办学性质</p>
                      <div class="gks-drop__grid">
                        <button v-for="n in NATURE_OPTS" :key="n" type="button" :class="['gks-drop__opt', { 'is-active': natureFilter === n }]" @click="natureFilter = n">{{ n }}</button>
                      </div>
                    </div>
                    <div class="gks-drop__group">
                      <p class="gks-drop__label">院校特色</p>
                      <div class="gks-drop__grid">
                        <button v-for="f in FEATURE_OPTS" :key="f" type="button" :class="['gks-drop__opt', { 'is-active': featureFilter === f }]" @click="featureFilter = f">{{ f }}</button>
                      </div>
                    </div>
                  </div>
                </template>
              </el-dropdown>

              <el-dropdown trigger="click" popper-class="gks-drop gks-drop--wide">
                <button type="button" class="gks-select">
                  <span :class="{ 'is-set': majorFilter !== '不限' }">{{ majorFilter === "不限" ? "专业" : majorFilter }}</span>
                  <el-icon><ArrowDown /></el-icon>
                </button>
                <template #dropdown>
                  <div class="gks-drop__groups">
                    <div class="gks-drop__group">
                      <p class="gks-drop__label">按专业大类筛选院校</p>
                      <div class="gks-drop__grid">
                        <button v-for="mj in MAJOR_OPTS" :key="mj" type="button" :class="['gks-drop__opt', { 'is-active': majorFilter === mj }]" @click="majorFilter = mj">{{ mj }}</button>
                      </div>
                    </div>
                  </div>
                </template>
              </el-dropdown>

              <el-dropdown trigger="click" popper-class="gks-drop gks-drop--sort">
                <button type="button" class="gks-select">
                  <span :class="{ 'is-set': sortKey !== '默认排序' }">{{ sortKey === "默认排序" ? "排序" : sortKey }}</span>
                  <el-icon><ArrowDown /></el-icon>
                </button>
                <template #dropdown>
                  <div class="gks-drop__col">
                    <button v-for="s in SORT_OPTS" :key="s" type="button" :class="['gks-drop__opt', { 'is-active': sortKey === s }]" @click="sortKey = s">{{ s }}</button>
                  </div>
                </template>
              </el-dropdown>

              <div class="gks-searchbar">
                <img class="gks-searchbar__icon" :src="searchIcon" alt="" />
                <input v-model="keyword" type="text" placeholder="输入院校名称" @keyup.enter="keyword = keyword.trim()" />
                <button type="button" @click="keyword = keyword.trim()">
                  <el-icon><Search /></el-icon>搜索
                </button>
              </div>
            </div>

            <p class="gks-count">院校 <b>{{ filtered.length }}</b> 所</p>
          </div>

          <ul class="gks-list">
            <li v-for="school in filtered" :key="school.id" class="gks-item" @click="askAdmission(school)">
              <GkSchoolLogo :school="school" size="page" />
              <div class="gks-item__info">
                <p class="gks-item__name">
                  {{ school.name }}<span class="gks-item__city">{{ schoolLoc(school) }}</span>
                  <img v-if="isHot(school)" class="gks-item__hot" :src="hotIcon" alt="热门" />
                </p>
                <p class="gks-item__core">本科 · {{ school.type }} · {{ school.nature }}</p>
                <p class="gks-item__tags">
                  <i v-for="tag in schoolTags(school)" :key="tag">{{ tag }}</i>
                </p>
              </div>
              <button class="gks-prob" type="button" @click.stop="askAdmission(school)">
                <span>录取概率</span>
                <b :class="`is-${probLevelOf(probabilityOf(school))}`">{{ probLevelOf(probabilityOf(school)) }}{{ probabilityOf(school) }}%</b>
              </button>
            </li>
            <li v-if="!filtered.length" class="gks-empty">没有符合条件的院校，试试放宽筛选条件</li>
          </ul>
        </section>

        <GkSidePanel />
      </div>
    </main>
  </div>
</template>
