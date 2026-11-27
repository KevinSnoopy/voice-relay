export interface AppTarget {
  id: string
  name: string
  hotkey: string
  tone: 'blue' | 'violet' | 'emerald' | 'amber' | 'rose' | 'cyan' | 'slate' | 'indigo' | 'teal'
}

export const APP_TARGETS: AppTarget[] = [
  { id: 'notes', name: '备忘录', hotkey: '⌘N', tone: 'amber' },
  { id: 'wechat', name: '微信', hotkey: '⌘F', tone: 'emerald' },
  { id: 'feishu', name: '飞书', hotkey: '⌘K', tone: 'blue' },
  { id: 'mail', name: '邮件', hotkey: '⌘M', tone: 'cyan' },
  { id: 'slack', name: 'Slack', hotkey: '⌘J', tone: 'violet' },
  { id: 'vscode', name: '编辑器', hotkey: '⌘P', tone: 'indigo' },
  { id: 'figma', name: '设计', hotkey: '⌘D', tone: 'rose' },
  { id: 'browser', name: '浏览器', hotkey: '⌘L', tone: 'teal' },
  { id: 'terminal', name: '终端', hotkey: '⌘T', tone: 'slate' },
]

export const QUICK_KEYS = [
  { label: '回车', desc: '发送 / 换行' },
  { label: 'Tab', desc: '切到下一个框' },
  { label: 'Esc', desc: '取消输入' },
  { label: '⌘A', desc: '全选' },
  { label: '⌘Z', desc: '撤销' },
  { label: '⌫', desc: '删一个字' },
]

export interface SampleLine {
  text: string
  at: string
  target: string
}

export const VOICE_SAMPLES: SampleLine[] = [
  { text: '把第三段的标题改短一点，下面两行跟上节奏。', at: '刚刚 09:42', target: '备忘录 · 项目周报' },
  { text: '周五下午两点前把方案发我，有问题随时找我。', at: '08:16', target: '微信 · 林工' },
  { text: '这版图的对齐我再看一遍，晚点同步。', at: '昨天 21:07', target: '飞书 · 设计组' },
]

export const ERROR_REASONS = [
  { code: 'no_focus', text: '当前没有可输入的位置', hint: '点一下输入框再试', icon: 'focus' },
  { code: 'timeout', text: '识别超时，没拿到文字', hint: '再说一次，靠近一点', icon: 'clock' },
  { code: 'net', text: '网络断了，字没送出去', hint: '检查 Wi-Fi 后重试', icon: 'wifi' },
  { code: 'permission', text: 'Mac 端没拿到输入权限', hint: '去 Mac 上开启后再试', icon: 'lock' },
] as const
