import { createApp } from "vue";
import ElementPlus from "element-plus";
import "element-plus/dist/index.css";
import App from "./App.vue";
import router from "./router";
import { isMockMode, setupMockInterceptor, MOCK_USER } from "./utils/mock";
import "./styles.css";

// 如果启用 Mock 模式，设置拦截器
if (isMockMode()) {
  setupMockInterceptor();
  // 演示模式预置演示账号：页面各处跳转 AI 对话时不再弹登录页，直达新版对话界面
  if (!localStorage.getItem("zhiyuan_auth")) {
    const { token, ...user } = MOCK_USER;
    localStorage.setItem("zhiyuan_auth", JSON.stringify({ token, user }));
  }
  console.log("[Mock Mode] 已启用演示模式，使用模拟数据");
}

createApp(App).use(ElementPlus).use(router).mount("#app");
