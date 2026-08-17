<script setup>
import { Search } from "@element-plus/icons-vue";
import { computed, onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import BrandLockup from "./BrandLockup.vue";
import XiaoZhiAvatar from "./XiaoZhiAvatar.vue";
import { clearStoredAuth, readStoredAuth, subjectTypeLabel } from "../utils/recommendation";

const props = defineProps({
  active: { type: String, default: "首页" },
  adminMode: { type: Boolean, default: false }
});

const router = useRouter();
const auth = ref(readStoredAuth());
const keyword = ref("");

const authMeta = computed(() => {
  const user = auth.value?.user || {};
  return [
    user.examProvince,
    subjectTypeLabel(user.subjectType),
    user.score == null || user.score === "" ? "" : `${user.score}分`
  ]
    .filter(Boolean)
    .join(" | ");
});

const NAV_ITEMS = [
  { label: "首页", to: { name: "home" } },
  { label: "查大学", to: { path: "/schools" } },
  { label: "查专业", to: { path: "/majors" } },
  { label: "志愿填报", to: { path: "/volunteer" } },
  { label: "智能选大学", to: { path: "/choose" } },
  { label: "高考资讯", to: { path: "/news" } }
];

const ADMIN_NAV_ITEMS = [
  { label: "用户管理", section: "users" },
  { label: "院校管理", section: "universities" },
  { label: "专业管理", section: "majors" },
  { label: "院校录取线", section: "cutoffs" },
  { label: "专业录取线", section: "majorCutoffs" }
];

function goAdminSection(section) {
  router.push({ name: "admin", query: section === "users" ? {} : { section } });
}

function goAgentWithQuestion(question) {
  router.push({ path: "/agent", query: question ? { q: question } : {} });
}

function submitSearch() {
  const question = String(keyword.value || "").trim();
  if (!question) {
    goAgentWithQuestion();
    return;
  }
  goAgentWithQuestion(`帮我查一下「${question}」相关院校`);
}

function logout() {
  clearStoredAuth();
  auth.value = null;
  router.push({ name: "login" });
}

onMounted(() => {
  auth.value = readStoredAuth();
});
</script>

<template>
  <header class="gk-home__topbar">
    <div class="gk-home__container gk-home__topbar-inner">
      <BrandLockup />
      <div v-if="!adminMode" class="gk-home__search">
        <el-icon class="gk-home__search-icon"><Search /></el-icon>
        <input
          v-model="keyword"
          class="gk-home__search-input"
          type="text"
          placeholder="输入大学 / 专业名称，让 AI 帮你分析"
          @keyup.enter="submitSearch"
        />
        <button class="gk-home__search-btn" type="button" @click="submitSearch">搜索</button>
      </div>
      <div v-else class="gk-admin__brand-tag">管理后台</div>
      <div class="gk-home__topbar-user">
        <template v-if="auth?.token">
          <span v-if="authMeta" class="gk-home__meta">{{ authMeta }}</span>
          <span class="gk-home__hello">Hi，{{ auth?.user?.username || "志愿考生" }}</span>
          <button class="gk-home__link-btn" type="button" @click="logout">退出</button>
        </template>
        <template v-else>
          <button class="gk-home__link-btn" type="button" @click="router.push({ name: 'login', query: { redirect: '/' } })">登录</button>
          <button class="gk-home__reg-btn" type="button" @click="router.push({ name: 'login', query: { redirect: '/' } })">免费注册</button>
        </template>
      </div>
    </div>
  </header>

  <nav class="gk-home__nav">
    <div class="gk-home__container gk-home__nav-inner">
      <template v-if="!adminMode">
        <button
          v-for="item in NAV_ITEMS"
          :key="item.label"
          type="button"
          class="gk-home__nav-item"
          :class="{ 'is-active': item.label === props.active }"
          @click="router.push(item.to)"
        >
          {{ item.label }}
        </button>
      </template>
      <template v-else>
        <button
          v-for="item in ADMIN_NAV_ITEMS"
          :key="item.section"
          type="button"
          class="gk-home__nav-item"
          :class="{ 'is-active': item.label === props.active }"
          @click="goAdminSection(item.section)"
        >
          {{ item.label }}
        </button>
      </template>
    </div>
  </nav>

  <aside
    v-if="!adminMode"
    class="gk-fab"
    title="问小智 · AI 报考助手"
    aria-label="问小智 · AI 报考助手"
    @click="goAgentWithQuestion()"
  >
    <span class="gk-fab__label">问小智 · 在线咨询</span>
    <span class="gk-fab__avatar">
      <XiaoZhiAvatar size="lg" />
      <span class="gk-fab__badge">AI</span>
    </span>
  </aside>
</template>
