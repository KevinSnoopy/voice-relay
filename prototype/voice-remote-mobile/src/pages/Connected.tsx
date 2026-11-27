import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { ChevronUp } from 'lucide-react'
import { VoiceHomeScreen } from '../components/VoiceHomeScreen'
import { useVoice } from '../store/voice'

export default function Connected() {
  const setConnected = useVoice((s) => s.setConnected)
  const navigate = useNavigate()
  void navigate

  useEffect(() => {
    setConnected(true)
  }, [setConnected])

  return <VoiceHomeScreen />
}

void useState
void ChevronUp
