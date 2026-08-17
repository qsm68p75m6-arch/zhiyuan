<script setup>
import { Promotion, Search } from "@element-plus/icons-vue";
import { computed, onMounted, ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import GkHeader from "../components/GkHeader.vue";
import GkSchoolLogo from "../components/GkSchoolLogo.vue";
import GkSidePanel from "../components/GkSidePanel.vue";
import { CHOOSE_OPTIONS, CHOOSE_PROBABILITIES, CHOOSE_SUBJECTS, buildChooseResults, schoolLoc, schoolTags } from "../utils/exploreData";

const router = useRouter();
const route = useRoute();
const subject = ref("物理");
const selections = ref([]);
const score = ref(620);
const rank = ref("");
const probability = ref("全部");
const submitted = ref(false);

onMounted(() => {
  const preset = Number(Array.isArray(route.query.score) ? route.query.score[0] : route.query.score);
  if (Number.isFinite(preset) && preset > 0 && preset <= 750) {
    score.value = preset;
    submitted.value = true;
  }
});

const results = computed(() =>
  buildChooseResults({ score: Number(score.value) || 0, subject: subject.value, selections: selections.value, probability: probability.value })
);

function toggleSelection(option) {
  const idx = selections.value.indexOf(option);
  if (idx >= 0) selections.value.splice(idx, 1);
  else if (selections.value.length < 2) selections.value.push(option);
}

function runChoose() {
  submitted.value = true;
}

function probClass(item) {
  if (item.prob === "概率大") return "is-high";
  if (item.prob === "概率中") return "is-mid";
  return "is-low";
}

function askSchool(item) {
  router.push({ path: "/agent", query: { q: `我${score.value}分，${item.name}${item.group}专业组去年最低${item.minScore}分/位次${item.minRank}，我被录取的概率有多大？` } });
}

function goRecommend() {
  router.push({
    path: "/agent",
    query: { q: "请按院校优先，帮我生成冲稳保梯度志愿方案" }
  });
}
</script>

<template>
  <div class="gk-page">
    <GkHeader active="智能选大学" />

    <main class="gk-home__container gk-page__main">
      <div class="gk-page__body">
        <section class="gk-page__content">
          <div class="gk-choose__hero">
            <div>
              <h2 class="gk-choose__title">智能选大学</h2>
              <p class="gk-choose__desc">输入科类、选科与分数，按报考概率为你匹配可报院校专业组</p>
            </div>
            <button class="gk-choose__ai" type="button" @click="goRecommend">
              <el-icon><Promotion /></el-icon>
              AI 方案版
            </button>
          </div>

          <div class="gk-filter">
            <div class="gk-filter__row">
              <span class="gk-filter__label">科类</span>
              <button
                v-for="s in CHOOSE_SUBJECTS"
                :key="s"
                type="button"
                class="gk-filter__opt"
                :class="{ 'is-active': subject === s }"
                @click="subject = s"
              >
                {{ s }}
              </button>
            </div>
            <div class="gk-filter__row">
              <span class="gk-filter__label">再选</span>
              <button
                v-for="o in CHOOSE_OPTIONS"
                :key="o"
                type="button"
                class="gk-filter__opt"
                :class="{ 'is-active': selections.includes(o) }"
                @click="toggleSelection(o)"
              >
                {{ o }}
              </button>
              <i class="gk-filter__tip">最多选 2 门</i>
            </div>
            <div class="gk-filter__row">
              <span class="gk-filter__label">分数</span>
              <input v-model.number="score" class="gk-choose__input" type="number" min="0" max="750" placeholder="高考分数" />
              <span class="gk-filter__label gk-choose__label2">位次</span>
              <input v-model="rank" class="gk-choose__input" type="text" placeholder="选填" />
              <button class="gk-choose__run" type="button" @click="runChoose">
                <el-icon><Search /></el-icon>
                开始匹配
              </button>
            </div>
            <div class="gk-filter__row">
              <span class="gk-filter__label">概率</span>
              <button
                v-for="p in CHOOSE_PROBABILITIES"
                :key="p"
                type="button"
                class="gk-filter__opt"
                :class="{ 'is-active': probability === p }"
                @click="probability = p"
              >
                {{ p }}
              </button>
            </div>
          </div>

          <p v-if="submitted" class="gk-page__meta">
            {{ subject }}类 {{ score }} 分 · {{ selections.length ? `再选${selections.join(" / ")}` : "再选不限" }} · 匹配到
            <b>{{ results.length }}</b> 个专业组
          </p>

          <ul v-if="submitted" class="gk-choose-list">
            <li v-for="item in results" :key="`${item.id}-${item.group}`" class="gk-choose">
              <GkSchoolLogo :school="item" />
              <div class="gk-choose__info">
                <p class="gk-school__name">
                  {{ item.name }}
                  <span class="gk-school__loc">@{{ schoolLoc(item) }}</span>
                  <span class="gk-choose__group">专业组({{ item.group }})</span>
                </p>
                <p class="gk-choose__rule">选科规则：{{ item.rule }}</p>
                <p class="gk-school__tags">
                  {{ item.type }} | {{ item.nature }}
                  <i v-for="tag in schoolTags(item)" :key="tag">{{ tag }}</i>
                </p>
              </div>
              <div class="gk-choose__nums">
                <p><b>{{ item.minScore }}</b><span>最低分</span></p>
                <p><b>{{ item.minRank.toLocaleString() }}</b><span>最低位次</span></p>
                <p class="gk-choose__rate">
                  <b>{{ item.rate }}%</b><span>专业录取率</span>
                </p>
              </div>
              <span class="gk-choose__prob" :class="probClass(item)">{{ item.prob }}</span>
              <button class="gk-school__action" type="button" @click="askSchool(item)">测概率 &gt;</button>
            </li>
            <li v-if="!results.length" class="gk-school__empty">没有匹配的专业组，试试调整分数或放宽概率筛选</li>
          </ul>

          <div v-else class="gk-choose__placeholder">
            <p class="gk-choose__ph-title">匹配前须知</p>
            <p class="gk-choose__ph-desc">
              结果基于历年录取数据与「冲稳保」梯度模型生成：概率大 = 分数显著高于专业组线，概率中 = 分数与专业组线相当，概率小 = 需要冲刺。
              填写左侧分数后点击「开始匹配」即可查看全部可报专业组。
            </p>
          </div>
        </section>

        <GkSidePanel />
      </div>
    </main>
  </div>
</template>
