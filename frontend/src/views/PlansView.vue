<script setup>
import { computed, inject, onMounted, onUnmounted, ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import GkHeader from "../components/GkHeader.vue";
import GkSchoolLogo from "../components/GkSchoolLogo.vue";
import GkSidePanel from "../components/GkSidePanel.vue";
import RecommendationResult from "../components/RecommendationResult.vue";
import { SCHOOLS } from "../utils/exploreData";
import { buildGroupedFromResult, formatDateTime, sourceTypeLabel } from "../utils/recommendation";
import { UI_TEXT } from "../utils/ui";

const router = useRouter();
const route = useRoute();

const {
  addCurrentPlanItem, clearCurrentPlan, currentPlanItems, deletePlan, invalidatePlanLoad,
  loadCurrentPlanDraft, loadPlans, openPlanDetail, planAiSummary, planDetail,
  planDetailLoading, planDialogVisible, planFinalAdvice, planGrouped,
  planHasResult, planRecommendationMode, planRecords,
  planResultJson, planSummary, planTips, removeCurrentPlanItem, resetPlanDialog, updatePlanDetailItems
} = inject("workspace");

const editing = ref(false);
const editSubmitting = ref(false);
const editableItems = ref([]);

/* ===== 工作台页签（mnzy /voluntary 同款） ===== */
const QUICK_TABS = [
  { key: "fill", label: "模拟填报", desc: "自选冲稳保院校" },
  { key: "plan", label: "定制方案", desc: "一键生成专属志愿", to: "/agent", q: "请基于我的分数位次和选科，一键生成专属冲稳保志愿方案" },
  { key: "table", label: "志愿表", desc: "我的方案列表" },
  { key: "diagnose", label: "防掉档诊断", desc: "掉档风险检查", to: "/agent", q: "帮我做一次志愿表防掉档诊断，检查梯度设置和掉档风险" }
];
const activeQuick = ref(["fill", "table"].includes(route.query.tab) ? route.query.tab : "fill");

function pickQuick(tab) {
  if (tab.to) {
    router.push({ path: tab.to, query: tab.q ? { q: tab.q } : {} });
    return;
  }
  activeQuick.value = tab.key;
}

function goAgentPlan() {
  router.push({ path: "/agent", query: { q: "请基于我的分数位次和选科，一键生成专属冲稳保志愿方案" } });
}

/* ===== 冲稳保计数（mnzy 同款 全部/冲击/稳妥/保底，可点击筛选） ===== */
const statCounts = computed(() => {
  let rush = 0;
  let safe = 0;
  let guarantee = 0;
  (planRecords.value || []).forEach((record) => {
    const counts = planCountsOf(record);
    rush += counts.rush;
    safe += counts.safe;
    guarantee += counts.guarantee;
  });
  return { all: rush + safe + guarantee, rush, safe, guarantee };
});

const chipFilter = ref("all");
const chipDefs = computed(() => [
  { key: "all", label: "全部", count: statCounts.value.all },
  { key: "rush", label: "冲击", count: statCounts.value.rush },
  { key: "safe", label: "稳妥", count: statCounts.value.safe },
  { key: "guarantee", label: "保底", count: statCounts.value.guarantee }
]);

function pickChip(key) {
  chipFilter.value = chipFilter.value === key && key !== "all" ? "all" : key;
}

/* ===== 院校库（模拟填报：选校加入志愿表） ===== */
const SCHOOL_TYPE_OPTS = ["不限", "综合", "理工"];
const FEATURE_OPTS = ["不限", "985", "211", "双一流"];
const SORT_OPTS = ["默认排序", "分数排序"];
const FEATURE_FIELD = { 985: "is985", 211: "is211", 双一流: "isDoubleFirstClass" };

const libSearch = ref("");
const libType = ref("不限");
const libFeature = ref("不限");
const libSort = ref("默认排序");

const baseScoreOf = (school) => 698 - school.id * 3 - (school.id % 5);
const probOf = (school) => 42 + ((school.id * 37) % 52);
const strategyOf = (school) => (school.id <= 5 ? { key: "rush", label: "冲" } : school.id <= 12 ? { key: "safe", label: "稳" } : { key: "guarantee", label: "保" });

const librarySchools = computed(() => {
  let list = SCHOOLS.filter((s) => {
    if (libSearch.value && !s.name.includes(libSearch.value)) return false;
    if (libType.value !== "不限" && !s.type.startsWith(libType.value)) return false;
    if (libFeature.value !== "不限" && !s[FEATURE_FIELD[libFeature.value]]) return false;
    if (chipFilter.value !== "all" && strategyOf(s).key !== chipFilter.value) return false;
    return true;
  }).map((s) => ({ ...s, baseScore: baseScoreOf(s), prob: probOf(s), strategy: strategyOf(s) }));
  if (libSort.value === "分数排序") list = [...list].sort((a, b) => b.baseScore - a.baseScore);
  else list = [...list].sort((a, b) => a.id - b.id);
  return list;
});

function addToPlan(school) {
  addCurrentPlanItem({
    universityName: school.name,
    majorName: "院校志愿",
    admissionProbability: school.prob,
    minRank: 120 + ((school.id * 41) % 60) * 37
  }, school.strategy.key);
}

/* ===== 志愿表页签：当前草稿冲稳保分组 ===== */
const draftRecord = computed(() => (planRecords.value || []).find((r) => r.planName === "当前方案草稿") || null);

const sheetGroups = computed(() => {
  const groups = { rush: [], safe: [], guarantee: [] };
  (currentPlanItems.value || []).forEach((item) => {
    const key = ["rush", "safe", "guarantee"].includes(item.strategy) ? item.strategy : "safe";
    groups[key].push(item);
  });
  return groups;
});

const sheetGroupList = computed(() => {
  const defs = [["rush", "冲击"], ["safe", "稳妥"], ["guarantee", "保底"]];
  let list = defs.map(([key, label]) => ({ key, label, items: sheetGroups.value[key] }));
  if (chipFilter.value !== "all") list = list.filter((g) => g.key === chipFilter.value);
  return list.filter((g) => g.items.length);
});

async function editDraft() {
  if (!draftRecord.value) {
    activeQuick.value = "fill";
    return;
  }
  await handleOpenPlan(draftRecord.value);
  startEditing();
}

/* ===== 我的方案卡片 ===== */
const savedPlans = computed(() => (planRecords.value || []).filter((r) => r.planName !== "当前方案草稿"));

function planCountsOf(record) {
  let parsed = null;
  try {
    parsed = record.resultJson ? JSON.parse(record.resultJson) : null;
  } catch {
    parsed = null;
  }
  if (!parsed) return { rush: 0, safe: 0, guarantee: 0 };
  const grouped = buildGroupedFromResult(parsed);
  return {
    rush: grouped.rush.length,
    safe: grouped.safe.length,
    guarantee: grouped.guarantee.length
  };
}

async function handleOpenPlan(row) {
  editing.value = false;
  await openPlanDetail(row);
}

function startEditing() {
  editableItems.value = [
    ...planGrouped.rush.map((item) => ({ ...item, strategy: "rush" })),
    ...planGrouped.safe.map((item) => ({ ...item, strategy: "safe" })),
    ...planGrouped.guarantee.map((item) => ({ ...item, strategy: "guarantee" }))
  ];
  editing.value = true;
}

function removeEditableItem(index) {
  editableItems.value.splice(index, 1);
}

async function saveEditing() {
  editSubmitting.value = true;
  try {
    if (await updatePlanDetailItems(editableItems.value)) {
      editing.value = false;
      await loadCurrentPlanDraft();
    }
  } finally {
    editSubmitting.value = false;
  }
}

onMounted(() => {
  loadPlans();
  loadCurrentPlanDraft();
});
onUnmounted(() => {
  invalidatePlanLoad();
  planDialogVisible.value = false;
  resetPlanDialog();
});
</script>

<template>
  <div class="gk-page">
    <GkHeader active="志愿填报" />

    <main class="gk-home__container gk-page__main">
      <div class="gk-page__body">
        <section class="gk-page__content">
          <div class="mnz-wb">
            <div class="mnz-wb__head">
              <div class="mnz-wb__heading">
                <h2 class="mnz-wb__title">我的志愿工作台</h2>
                <p class="mnz-wb__desc">模拟填报自选院校，或让 AI 按分数位次一键定制冲稳保方案</p>
              </div>
              <button type="button" class="mnz-wb__ai" @click="goAgentPlan"><i>AI</i>一键定制方案</button>
            </div>

            <nav class="mnz-wb__tabs">
              <button
                v-for="tab in QUICK_TABS"
                :key="tab.key"
                type="button"
                class="mnz-wb__tab"
                :class="{ 'is-active': activeQuick === tab.key }"
                @click="pickQuick(tab)"
              >
                <strong>{{ tab.label }}</strong>
                <span>{{ tab.desc }}</span>
              </button>
            </nav>

            <div class="mnz-wb__stats">
              <button
                v-for="chip in chipDefs"
                :key="chip.key"
                type="button"
                class="mnz-stat"
                :class="[`is-${chip.key}`, { 'is-active': chipFilter === chip.key }]"
                @click="pickChip(chip.key)"
              >
                <em>{{ chip.label }}</em><b>{{ chip.count }}</b>
              </button>
            </div>

            <!-- 模拟填报：院校库选校 -->
            <div v-if="activeQuick === 'fill'" class="mnz-lib">
              <div class="mnz-lib__bar">
                <div class="mnz-search">
                  <input v-model.trim="libSearch" type="text" placeholder="输入院校名称搜索" />
                  <button type="button">搜索</button>
                </div>
                <div class="mnz-lib__filters">
                  <el-select v-model="libType" size="default" class="mnz-lib__select" aria-label="院校类型">
                    <el-option v-for="o in SCHOOL_TYPE_OPTS" :key="o" :label="o === '不限' ? '类型' : o + '类'" :value="o" />
                  </el-select>
                  <el-select v-model="libFeature" size="default" class="mnz-lib__select" aria-label="院校特色">
                    <el-option v-for="o in FEATURE_OPTS" :key="o" :label="o === '不限' ? '特色' : o" :value="o" />
                  </el-select>
                  <el-select v-model="libSort" size="default" class="mnz-lib__select mnz-lib__select--sort" aria-label="排序">
                    <el-option v-for="o in SORT_OPTS" :key="o" :label="o" :value="o" />
                  </el-select>
                </div>
              </div>

              <div v-if="librarySchools.length" class="mnz-lib__hint">根据您的批次或成绩，从下方院校库自选冲稳保院校加入志愿表</div>

              <ul v-if="librarySchools.length" class="mnz-lib__list">
                <li v-for="school in librarySchools" :key="school.id" class="mnz-lib__item">
                  <GkSchoolLogo :school="school" size="page" />
                  <div class="mnz-lib__info">
                    <p class="mnz-lib__name">
                      {{ school.name }}
                      <i class="mnz-lib__tag" :class="`is-${school.strategy.key}`">{{ school.strategy.label }}</i>
                    </p>
                    <p class="mnz-lib__meta">
                      {{ school.province }} · {{ school.type }} · {{ school.nature }}
                      <template v-if="school.is985"> · 985</template>
                      <template v-if="school.is211"> · 211</template>
                    </p>
                  </div>
                  <div class="mnz-lib__side">
                    <span class="mnz-lib__prob">录取概率 {{ school.prob }}%</span>
                    <span class="mnz-lib__score">最低分 {{ school.baseScore }}</span>
                  </div>
                  <button type="button" class="mnz-lib__add" @click="addToPlan(school)">加入志愿表</button>
                </li>
              </ul>
              <div v-else class="mnz-empty">
                <p class="mnz-empty__title">没有符合条件的院校</p>
                <p class="mnz-empty__desc">换个关键词，或把类型 / 特色筛选放宽一些</p>
                <div class="mnz-empty__ops">
                  <button type="button" class="mnz-empty__btn" @click="libSearch = ''; libType = '不限'; libFeature = '不限'; chipFilter = 'all'">清除筛选</button>
                </div>
              </div>
            </div>

            <!-- 志愿表：草稿分组 + 我的方案 -->
            <template v-else-if="activeQuick === 'table'">
              <div class="mnz-sheet">
                <div class="mnz-sheet__head">
                  <p class="mnz-sheet__title">当前志愿表<em>草稿 · {{ (currentPlanItems || []).length }} 条</em></p>
                  <div v-if="(currentPlanItems || []).length" class="mnz-sheet__ops">
                    <button type="button" class="mnz-sheet__op" @click="editDraft">编辑志愿表</button>
                    <button type="button" class="mnz-sheet__op is-danger" @click="clearCurrentPlan">清空</button>
                  </div>
                </div>

                <template v-if="(currentPlanItems || []).length">
                  <div v-for="group in sheetGroupList" :key="group.key" class="mnz-sheet__group">
                    <p class="mnz-sheet__gtitle" :class="`is-${group.key}`">{{ group.label }}<em>{{ group.items.length }} 条</em></p>
                    <div v-for="(item, i) in group.items" :key="item.planKey || i" class="mnz-sheet__row">
                      <i class="mnz-sheet__idx" :class="`is-${group.key}`">{{ i + 1 }}</i>
                      <div class="mnz-sheet__info">
                        <p class="mnz-sheet__name">{{ item.universityName }}</p>
                        <p class="mnz-sheet__major">{{ item.majorName || "院校志愿" }}</p>
                      </div>
                      <span class="mnz-sheet__prob">录取概率 {{ item.admissionProbability == null ? "-" : `${item.admissionProbability}%` }}</span>
                      <span class="mnz-sheet__rank">位次 {{ item.minRank ?? "-" }}</span>
                      <button type="button" class="mnz-sheet__remove" @click="removeCurrentPlanItem(item)">移除</button>
                    </div>
                  </div>
                </template>

                <div v-else class="mnz-empty">
                  <p class="mnz-empty__title">志愿表还是空的</p>
                  <p class="mnz-empty__desc">从院校库自选冲稳保院校，或让 AI 按你的分数位次一键生成</p>
                  <div class="mnz-empty__ops">
                    <button type="button" class="mnz-empty__btn" @click="activeQuick = 'fill'">去模拟填报</button>
                    <button type="button" class="mnz-empty__btn is-ghost" @click="goAgentPlan">AI 定制方案</button>
                  </div>
                </div>
              </div>

              <div class="mnz-plans">
                <div class="mnz-plans__head">
                  <p class="mnz-sheet__title">我的方案<em>已保存 {{ savedPlans.length }} 份</em></p>
                </div>
                <div v-if="savedPlans.length" class="mnz-plans__grid">
                  <div v-for="record in savedPlans" :key="record.id" class="mnz-plan">
                    <div class="mnz-plan__top">
                      <p class="mnz-plan__name">{{ record.planName }}</p>
                      <span class="mnz-plan__source">{{ sourceTypeLabel(record.sourceType) }}</span>
                    </div>
                    <p class="mnz-plan__meta">{{ formatDateTime(record.createdAt) }}</p>
                    <div class="mnz-plan__tags">
                      <i class="is-rush">冲 {{ planCountsOf(record).rush }}</i>
                      <i class="is-safe">稳 {{ planCountsOf(record).safe }}</i>
                      <i class="is-guarantee">保 {{ planCountsOf(record).guarantee }}</i>
                    </div>
                    <div class="mnz-plan__ops">
                      <button type="button" @click="handleOpenPlan(record)">查看详情</button>
                      <button type="button" class="is-danger" @click="deletePlan(record)">删除</button>
                    </div>
                  </div>
                </div>
                <div v-else class="mnz-plans__blank">暂无保存的方案，AI 定制或编辑志愿表后会自动保存</div>
              </div>
            </template>
          </div>
        </section>

        <GkSidePanel />
      </div>
    </main>

    <el-dialog v-model="planDialogVisible" title="方案详情" width="80%" top="4vh" destroy-on-close>
      <el-skeleton :loading="planDetailLoading" animated>
        <template #template>
          <el-skeleton-item variant="h1" style="width: 50%;" />
          <el-skeleton-item variant="text" style="margin-top: 8px;" />
          <el-skeleton-item variant="text" />
        </template>
        <template #default>
          <div v-if="planDetail" class="history-detail-meta">
            <el-descriptions :column="1" border>
              <el-descriptions-item label="方案名称">{{ planDetail.planName }}</el-descriptions-item>
              <el-descriptions-item label="来源类型">{{ sourceTypeLabel(planDetail.sourceType) }}</el-descriptions-item>
              <el-descriptions-item label="创建时间">{{ formatDateTime(planDetail.createdAt) }}</el-descriptions-item>
              <el-descriptions-item label="来源内容">{{ planDetail.sourceQuery }}</el-descriptions-item>
            </el-descriptions>
          </div>
          <div v-if="planHasResult" class="plan-detail-toolbar">
            <div>
              <strong>{{ planDetail.planName }}</strong>
              <span>共 {{ planGrouped.rush.length + planGrouped.safe.length + planGrouped.guarantee.length }} 条志愿</span>
            </div>
            <div>
              <el-button v-if="!editing" type="primary" plain @click="startEditing">编辑志愿表</el-button>
              <template v-else>
                <el-button @click="editing = false">取消</el-button>
                <el-button type="primary" :loading="editSubmitting" @click="saveEditing">保存修改</el-button>
              </template>
            </div>
          </div>

          <div v-if="editing" class="plan-editor-list">
            <div v-for="(item, index) in editableItems" :key="`${item.universityName}-${item.majorName}-${index}`" class="plan-editor-item">
              <div class="plan-editor-item__identity">
                <strong>{{ item.universityName }}</strong>
                <span>{{ item.majorName || "院校志愿" }}</span>
              </div>
              <div class="plan-editor-item__metrics">
                <span>录取概率 {{ item.admissionProbability == null ? "-" : `${item.admissionProbability}%` }}</span>
                <span>位次 {{ item.minRank ?? "-" }}</span>
              </div>
              <el-select v-model="item.strategy" class="plan-editor-item__strategy" aria-label="志愿档位">
                <el-option label="冲刺" value="rush" />
                <el-option label="稳妥" value="safe" />
                <el-option label="保底" value="guarantee" />
              </el-select>
              <el-button type="danger" link @click="removeEditableItem(index)">删除</el-button>
            </div>
            <el-empty v-if="!editableItems.length" description="该志愿表暂无志愿" :image-size="80" />
          </div>

          <RecommendationResult v-else-if="planHasResult" :loading="false" :grouped="planGrouped" :summary="planSummary" :ai-summary="planAiSummary" :final-advice="planFinalAdvice" :tips="planTips" :recommendation-mode="planRecommendationMode" />
          <el-card v-else shadow="never" class="history-raw-card">
            <template #header>原始结果</template>
            <pre class="history-raw">{{ planResultJson || UI_TEXT.common.noDisplayContent }}</pre>
          </el-card>
        </template>
      </el-skeleton>
    </el-dialog>
  </div>
</template>

<style scoped>
.plan-detail-toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin: 16px 0;
  padding: 12px 16px;
  border: 1px solid var(--border, #e6ebf2);
  border-radius: 10px;
  background: #f8fbff;
}

.plan-detail-toolbar strong {
  margin-right: 12px;
  font-size: 16px;
}

.plan-detail-toolbar span {
  color: #64748b;
  font-size: 13px;
}

.plan-editor-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
  margin-top: 16px;
}

.plan-editor-item {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 14px 16px;
  border: 1px solid var(--border, #e6ebf2);
  border-radius: 12px;
  background: linear-gradient(180deg, #fbfdff 0%, #ffffff 100%);
}

.plan-editor-item__identity {
  flex: 1;
  min-width: 0;
}

.plan-editor-item__identity strong {
  display: block;
  font-size: 14px;
  line-height: 1.4;
}

.plan-editor-item__identity span {
  display: block;
  margin-top: 2px;
  color: #64748b;
  font-size: 13px;
}

.plan-editor-item__metrics {
  display: flex;
  gap: 16px;
  color: #64748b;
  font-size: 13px;
  flex-shrink: 0;
}

.plan-editor-item__strategy {
  width: 120px;
  flex-shrink: 0;
}

.history-raw {
  margin: 0;
  white-space: pre-wrap;
  word-break: break-all;
  font-size: 12px;
  color: #334155;
  line-height: 1.6;
}
</style>
