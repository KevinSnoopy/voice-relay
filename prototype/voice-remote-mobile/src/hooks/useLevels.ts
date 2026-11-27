import { useEffect, useRef, useState } from 'react'

export interface LevelOptions {
  /** 是否正在收音；false 时缓慢回落为静止细线 */
  active: boolean
  /** 静音强度 0-1，越大波动越大 */
  intensity?: number
  bars?: number
}

const BASE = [0.18, 0.34, 0.52, 0.34, 0.18]

/**
 * 每帧插值生成电平值（60 fps，无额外缓动），
 * 从触发到第一帧跳动 < 100 ms。
 */
export function useLevels({ active, intensity = 1, bars = 5 }: LevelOptions) {
  const [levels, setLevels] = useState<number[]>(() => BASE.slice(0, bars))
  const target = useRef<number[]>(BASE.slice(0, bars))
  const current = useRef<number[]>(BASE.slice(0, bars))
  const raf = useRef<number | null>(null)

  useEffect(() => {
    const tick = () => {
      if (active) {
        const t = performance.now() / 1000
        target.current = Array.from({ length: bars }, (_, i) => {
          const wave =
            Math.abs(Math.sin(t * (2.4 + i * 0.55) + i * 1.3)) * 0.55 +
            Math.abs(Math.sin(t * (5.1 + i * 0.3))) * 0.3 +
            Math.random() * 0.22
          return Math.min(1, Math.max(0.08, wave * intensity))
        })
      } else {
        target.current = BASE.slice(0, bars).map((v) => v * 0.35)
      }
      current.current = current.current.map((v, i) => v + (target.current[i] - v) * 0.35)
      setLevels([...current.current])
      raf.current = requestAnimationFrame(tick)
    }
    raf.current = requestAnimationFrame(tick)
    return () => {
      if (raf.current) cancelAnimationFrame(raf.current)
    }
  }, [active, bars, intensity])

  return levels
}
