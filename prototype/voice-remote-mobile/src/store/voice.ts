import { create } from 'zustand'

export type Backend = 'local' | 'ime'

export type PermissionKey = 'microphone' | 'localNetwork' | 'bluetooth'
export type PermissionStatus = 'unknown' | 'granted' | 'denied'

export interface LastText {
  text: string
  createdAt: number
  /** 上屏是否成功；失败时保留文本供复制 */
  delivered: 'success' | 'submitted' | 'failed' | null
  reason?: string
  target?: string
}

export interface DiscoveredMac {
  id: string
  name: string
  strength: number
  detail: string
}

export const MAC_PRIMARY = 'Studio · 设计台'

export const MAC_LIST: DiscoveredMac[] = [
  { id: 'studio', name: 'Studio · 设计台', strength: 4, detail: '信号很好 · 同一网络' },
  { id: 'macbook', name: '周屿的 MacBook Air', strength: 3, detail: '信号良好 · 配对过' },
  { id: 'mini', name: '会议室 Mac mini', strength: 1, detail: '信号较弱 · 需确认' },
]

export const PERMISSION_META: Record<
  PermissionKey,
  { title: string; hint: string; why: string; required: boolean }
> = {
  microphone: {
    title: '麦克风',
    hint: '收音必需',
    why: '不给权限，按钮按下去也没有声音。',
    required: true,
  },
  localNetwork: {
    title: '本地网络',
    hint: 'iOS 首次访问时询问',
    why: 'Android 无需单独授权；发现或连接成功后显示已验证。',
    required: false,
  },
  bluetooth: {
    title: '蓝牙',
    hint: '可选，备用通道',
    why: '网络不通时改走蓝牙，更稳。',
    required: false,
  },
}

export interface VoiceState {
  connected: boolean
  macName: string
  backend: Backend
  permissions: Record<PermissionKey, PermissionStatus>
  paired: boolean
  last: LastText
  activeApp: string
  errorMode: string | null
  haptic: boolean
  sound: boolean
  autoWake: boolean
  stream: boolean

  setConnected: (v: boolean) => void
  setBackend: (b: Backend) => void
  setPermission: (key: PermissionKey, status: PermissionStatus) => void
  grantAll: () => void
  pair: (macName: string) => void
  saveLast: (text: string, delivered: LastText['delivered'], reason?: string, target?: string) => void
  markDelivered: (delivered: 'success' | 'submitted' | 'failed', reason?: string) => void
  setActiveApp: (name: string) => void
  setErrorMode: (mode: string | null) => void
  toggle: (key: 'haptic' | 'sound' | 'autoWake' | 'stream') => void
}

export const useVoice = create<VoiceState>((set) => ({
  connected: true,
  macName: MAC_PRIMARY,
  backend: 'local',
  permissions: { microphone: 'granted', localNetwork: 'unknown', bluetooth: 'unknown' },
  paired: true,
  last: {
    text: '把第三段的标题改短一点，下面两行跟上节奏。',
    createdAt: Date.now() - 1000 * 60 * 6,
    delivered: 'success',
    target: '备忘录 · 项目周报',
  },
  activeApp: '备忘录',
  errorMode: null,
  haptic: true,
  sound: false,
  autoWake: true,
  stream: false,

  setConnected: (v) => set({ connected: v }),
  setBackend: (b) => set({ backend: b }),
  setPermission: (key, status) =>
    set((s) => ({ permissions: { ...s.permissions, [key]: status } })),
  grantAll: () =>
    set({
      permissions: { microphone: 'granted', localNetwork: 'granted', bluetooth: 'granted' },
    }),
  pair: (macName) => set({ connected: true, paired: true, macName, errorMode: null }),
  saveLast: (text, delivered, reason, target) =>
    set({ last: { text, createdAt: Date.now(), delivered, reason, target } }),
  markDelivered: (delivered, reason) =>
    set((s) => ({ last: { ...s.last, delivered, reason: reason ?? s.last.reason } })),
  setActiveApp: (name) => set({ activeApp: name }),
  setErrorMode: (mode) => set({ errorMode: mode }),
  toggle: (key) => set((s) => ({ [key]: !s[key] }) as Partial<VoiceState>),
}))
