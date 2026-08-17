<script setup>
import { computed, ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import GkHeader from "../components/GkHeader.vue";
import GkSidePanel from "../components/GkSidePanel.vue";
import VolunteerSheet from "../components/VolunteerSheet.vue";
import { CITY_DESTINATIONS, VOLUNTEER_MAJOR_TOP, VOLUNTEER_SCHOOL_TOP, VOLUNTEER_STATS } from "../utils/exploreData";

const router = useRouter();
const route = useRoute();
const cityTab = ref("本省");

/* ===== 两阶段：信息表单 → 完整志愿填报器（参考 mnzy.gaokao.cn） ===== */
const stage = ref("form");
const sheetRef = ref(null);

const sheetProfile = computed(() => ({
  province: province.value,
  subjects: [...subjects.value],
  score: score.value,
  rank: rank.value,
  batch: batch.value,
  degreeType: degreeType.value
}));

function startFill() {
  stage.value = "sheet";
  window.scrollTo({ top: 0, behavior: "smooth" });
}

function backToForm() {
  stage.value = "form";
  window.scrollTo({ top: 0, behavior: "smooth" });
}

/* 推荐页"去看志愿表"直达填报器 */
if (String(route.query.autostart || "") === "1") {
  stage.value = "sheet";
}

/* ===== 高考信息表单（复刻 mnzy.gaokao.cn 填报信息弹窗） ===== */
const ENTRANT_TYPES = [
  { key: "general", label: "普通类" },
  { key: "art", label: "艺术类" }
];
const PROVINCES = ["北京", "天津", "河北", "山西", "内蒙古", "辽宁", "吉林", "黑龙江", "上海", "江苏", "浙江", "安徽", "福建", "江西", "山东", "河南", "湖北", "湖南", "广东", "广西", "海南", "重庆", "四川", "贵州", "云南", "陕西", "甘肃", "青海", "宁夏", "新疆"];
const GRADES = ["高三", "高二", "高一"];
const SUBJECTS = ["物理", "化学", "生物", "政治", "历史", "地理"];
const BATCHES = ["本科批", "专科批"];

const entrantType = ref("general");
const province = ref("湖南");
const grade = ref("高三");
const degreeType = ref("本科");
const subjects = ref(["物理", "化学", "生物"]);
const score = ref(560);
const batch = ref("本科批");

const rank = computed(() => Math.max(50, Math.round((720 - Number(score.value || 0)) * 240)));

function toggleSubject(name) {
  const idx = subjects.value.indexOf(name);
  if (idx >= 0) subjects.value.splice(idx, 1);
  else if (subjects.value.length < 3) subjects.value.push(name);
}

function customizePlan() {
  const q = `我是${province.value}考生，${degreeType.value}${batch.value}，选科${subjects.value.join("")}，预估${score.value}分（位次约${rank.value}名），请一键生成我的专属冲稳保志愿方案`;
  router.push({ path: "/agent", query: { q } });
}

function simulateFill() {
  startFill();
}

function goDiagnose() {
  router.push({ path: "/agent", query: { q: "帮我做一次志愿表防掉档诊断，检查梯度设置和掉档风险" } });
}

/* ===== 大数据看板（原有内容） ===== */
function schoolRows() {
  return VOLUNTEER_SCHOOL_TOP.slice(0, 9);
}
function majorRows() {
  return VOLUNTEER_MAJOR_TOP.slice(0, 9);
}
function rowsOf(list) {
  const rows = [];
  for (let i = 0; i < list.length; i += 3) rows.push(list.slice(i, i + 3));
  return rows;
}

function goPlans() {
  router.push({ path: "/plans" });
}
function goAgent() {
  router.push({ path: "/agent", query: { q: "帮我分析一下今年的志愿填报趋势，哪些院校和专业最热门？" } });
}
</script>

<template>
  <div class="gk-page">
    <GkHeader active="志愿填报" />

    <main class="gk-home__container gk-page__main">
      <div class="gk-page__body">
        <section class="gk-page__content">
          <template v-if="stage === 'form'">
          <!-- 高考信息表单（mnzy 同款） -->
          <div class="mnz-form">
            <p class="mnz-form__title">请填写您的高考信息</p>

            <div class="mnz-form__row mnz-form__row--entrant">
              <button
                v-for="t in ENTRANT_TYPES"
                :key="t.key"
                type="button"
                class="mnz-entrant"
                :class="{ 'is-active': entrantType === t.key }"
                @click="entrantType = t.key"
              >
                <i :class="`mnz-entrant__icon mnz-entrant__icon--${t.key}`">{{ t.key === "general" ? "学" : "艺" }}</i>
                <span>{{ t.label }}</span>
              </button>
            </div>

            <div class="mnz-form__grid">
              <label class="mnz-field">
                <span class="mnz-field__label">考试地区</span>
                <el-select v-model="province" size="large">
                  <el-option v-for="p in PROVINCES" :key="p" :label="p" :value="p" />
                </el-select>
              </label>
              <label class="mnz-field">
                <span class="mnz-field__label">所属年级</span>
                <el-select v-model="grade" size="large">
                  <el-option v-for="g in GRADES" :key="g" :label="g" :value="g" />
                </el-select>
              </label>
              <div class="mnz-field">
                <span class="mnz-field__label">成绩类型</span>
                <div class="mnz-field__opts">
                  <button
                    v-for="d in ['本科', '专科']"
                    :key="d"
                    type="button"
                    class="mnz-radio"
                    :class="{ 'is-active': degreeType === d }"
                    @click="degreeType = d"
                  >
                    {{ d }}
                  </button>
                </div>
              </div>
              <div class="mnz-field">
                <span class="mnz-field__label">填报批次</span>
                <el-select v-model="batch" size="large">
                  <el-option label="本科批" value="本科批">
                    <span class="mnz-batch__option">本科批<em class="mnz-batch__tag">推荐</em></span>
                  </el-option>
                  <el-option v-for="b in BATCHES.filter((x) => x !== '本科批')" :key="b" :label="b" :value="b" />
                </el-select>
              </div>
            </div>

            <div class="mnz-form__row">
              <span class="mnz-form__label">高考科目</span>
              <div class="mnz-form__subjects">
                <button
                  v-for="s in SUBJECTS"
                  :key="s"
                  type="button"
                  class="mnz-subject"
                  :class="{ 'is-active': subjects.includes(s) }"
                  @click="toggleSubject(s)"
                >
                  {{ s }}
                </button>
                <em class="mnz-form__hint">已选 {{ subjects.length }}/3</em>
              </div>
            </div>

            <div class="mnz-form__grid mnz-form__grid--scores">
              <label class="mnz-field">
                <span class="mnz-field__label">预估分数</span>
                <el-input v-model.number="score" size="large" type="number" min="0" max="750">
                  <template #suffix>分</template>
                </el-input>
              </label>
              <div class="mnz-field">
                <span class="mnz-field__label">对应位次</span>
                <div class="mnz-rank">
                  {{ rank.toLocaleString("en-US") }}<i>名</i>
                </div>
              </div>
            </div>

            <div class="mnz-form__actions">
              <button type="button" class="mnz-cta mnz-cta--ghost" @click="customizePlan">
                <span>定制方案</span>
                <span class="mnz-cta__sub">一键生成专属志愿</span>
              </button>
              <button type="button" class="mnz-cta mnz-cta--solid" @click="simulateFill">
                <span>模拟填报</span>
                <span class="mnz-cta__sub">自选冲稳保院校</span>
              </button>
            </div>
          </div>

          <!-- 快捷入口（mnzy 顶栏同款四入口） -->
          <div class="mnz-quick">
            <button type="button" class="mnz-quick__item" @click="startFill">
              <i class="mnz-quick__icon">智</i>智能填报
            </button>
            <button type="button" class="mnz-quick__item" @click="goPlans">
              <i class="mnz-quick__icon">表</i>志愿表
            </button>
            <button type="button" class="mnz-quick__item" @click="goDiagnose">
              <i class="mnz-quick__icon">诊</i>防掉档诊断
            </button>
            <button type="button" class="mnz-quick__item" @click="goAgent">
              <i class="mnz-quick__icon">问</i>问小智
            </button>
          </div>

          <div class="gk-volunteer__hero">
            <div class="gk-volunteer__hero-text">
              <h2 class="gk-volunteer__title">志愿填报大数据</h2>
              <p class="gk-volunteer__desc">基于平台用户的模拟填报行为，实时呈现院校、专业与城市热度，为你的志愿决策提供参考</p>
            </div>
            <button class="gk-volunteer__cta" type="button" @click="startFill">开始智能填报</button>
          </div>

          <ul class="gk-vol-stats">
            <li v-for="stat in VOLUNTEER_STATS" :key="stat.label" class="gk-vol-stat">
              <p class="gk-vol-stat__value">{{ stat.value }}<i>{{ stat.unit }}</i></p>
              <p class="gk-vol-stat__label">{{ stat.label }}</p>
              <p class="gk-vol-stat__desc">{{ stat.desc }}</p>
            </li>
          </ul>

          <section class="gk-vol-board">
            <h3 class="gk-vol-board__title">填报院校 TOP<em>按模拟填报人次排序</em></h3>
            <div v-for="(row, ri) in rowsOf(schoolRows())" :key="`s-${ri}`" class="gk-vol-board__row">
              <div v-for="(item, ci) in row" :key="item.name" class="gk-vol-item">
                <i class="gk-vol-item__rank" :class="{ 'is-top': ri * 3 + ci < 3 }">{{ ri * 3 + ci + 1 }}</i>
                <span class="gk-vol-item__name">{{ item.name }}</span>
                <span class="gk-vol-item__count">{{ item.count.toLocaleString() }} 人次</span>
              </div>
            </div>
          </section>

          <section class="gk-vol-board">
            <h3 class="gk-vol-board__title">填报专业 TOP<em>按模拟填报人次排序</em></h3>
            <div v-for="(row, ri) in rowsOf(majorRows())" :key="`m-${ri}`" class="gk-vol-board__row">
              <div v-for="(item, ci) in row" :key="item.name" class="gk-vol-item">
                <i class="gk-vol-item__rank" :class="{ 'is-top': ri * 3 + ci < 3 }">{{ ri * 3 + ci + 1 }}</i>
                <span class="gk-vol-item__name">{{ item.name }}</span>
                <span class="gk-vol-item__count">{{ item.count.toLocaleString() }} 人次</span>
              </div>
            </div>
          </section>

          <section class="gk-vol-board">
            <h3 class="gk-vol-board__title">
              城市去向排行
              <span class="gk-vol-board__tabs">
                <button v-for="t in ['本省', '省外']" :key="t" type="button" :class="{ 'is-active': cityTab === t }" @click="cityTab = t">
                  {{ t }}
                </button>
              </span>
            </h3>
            <ul class="gk-vol-city">
              <li v-for="(city, i) in CITY_DESTINATIONS[cityTab]" :key="city.name" class="gk-vol-city__row">
                <i class="gk-vol-item__rank" :class="{ 'is-top': i < 3 }">{{ i + 1 }}</i>
                <span class="gk-vol-item__name">{{ city.name }}</span>
                <span class="gk-vol-city__bar">
                  <b :style="{ width: `${Math.round((city.count / CITY_DESTINATIONS[cityTab][0].count) * 100)}%` }" />
                </span>
                <span class="gk-vol-item__count">{{ city.count.toLocaleString() }} 人</span>
              </li>
            </ul>
          </section>

          <div class="gk-vol-entries">
            <button type="button" class="gk-vol-entry" @click="startFill">
              <strong>智能志愿推荐</strong>
              <span>输入分数位次，生成冲稳保方案</span>
              <em>立即使用 ›</em>
            </button>
            <button type="button" class="gk-vol-entry" @click="goPlans">
              <strong>我的志愿表</strong>
              <span>管理已收藏院校，动态跟踪方案</span>
              <em>前往管理 ›</em>
            </button>
            <button type="button" class="gk-vol-entry" @click="goAgent">
              <strong>AI 填报答疑</strong>
              <span>梯度怎么拉开的？服从调剂稳吗？直接问</span>
              <em>问小智 ›</em>
            </button>
          </div>
          </template>

          <div v-else class="mnz-vfill">
            <div class="mnz-vfill__top">
              <button type="button" class="mnz-vfill__back" @click="backToForm">‹ 返回修改信息</button>
              <div class="mnz-vfill__heading">
                <h3>志愿填报器</h3>
                <span>45 个志愿位 · 拖拽排序 · 智能填充 · 防掉档诊断</span>
              </div>
              <button type="button" class="mnz-vfill__op" @click="sheetRef && sheetRef.smartFill()">一键智能填充</button>
            </div>
            <VolunteerSheet ref="sheetRef" :profile="sheetProfile" :initial-tab="String(route.query.tab || 'pick')" :initial-view="String(route.query.view || 'detail')" />
          </div>
        </section>

        <GkSidePanel />
      </div>
    </main>
  </div>
</template>
