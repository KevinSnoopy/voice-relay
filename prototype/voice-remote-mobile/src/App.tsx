import { AnimatePresence, motion } from 'framer-motion'
import { Route, Routes, useLocation } from 'react-router-dom'
import Index from './pages/Index'
import Welcome from './pages/Welcome'
import Permissions from './pages/Permissions'
import Discover from './pages/Discover'
import ScanPair from './pages/ScanPair'
import Connected from './pages/Connected'
import Listening from './pages/Listening'
import Recognizing from './pages/Recognizing'
import Delivered from './pages/Delivered'
import Failed from './pages/Failed'
import Settings from './pages/Settings'
import Reconnect from './pages/Reconnect'
import Disconnected from './pages/Disconnected'
import Components from './pages/Components'

function Page({ children }: { children: React.ReactNode }) {
  return <div className="h-full min-h-0 w-full">{children}</div>
}

export default function App() {
  const location = useLocation()
  const isIndex = location.pathname === '/'

  return (
    <div className="flex h-full min-h-0 w-full flex-col overflow-hidden bg-white">
      <main className={isIndex ? 'min-h-0 flex-1 overflow-hidden' : 'mx-auto flex min-h-0 w-full flex-1 justify-center overflow-hidden px-0 py-0 sm:px-6 sm:py-5' }>
        <div className={isIndex ? 'h-full min-h-0 w-full' : 'flex h-full min-h-0 w-full max-w-[430px] flex-col overflow-hidden rounded-none bg-white shadow-[0_24px_70px_-30px_rgba(15,23,42,0.35)] sm:rounded-[32px] sm:ring-1 sm:ring-slate-200' }>
          <AnimatePresence mode="wait" initial={false}>
            <motion.div
              key={location.pathname}
              initial={{ opacity: 0, y: 6 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 0.2, ease: 'easeOut' }}
              className="relative h-full min-h-0 w-full"
            >
              <Routes location={location}>
                <Route path="/" element={<Page><Index /></Page>} />
                <Route path="/m01" element={<Page><Welcome /></Page>} />
                <Route path="/m02" element={<Page><Permissions /></Page>} />
                <Route path="/m03" element={<Page><Discover /></Page>} />
                <Route path="/m04" element={<Page><ScanPair /></Page>} />
                <Route path="/m05" element={<Page><Connected /></Page>} />
                <Route path="/m06" element={<Page><Listening /></Page>} />
                <Route path="/m07" element={<Page><Recognizing /></Page>} />
                <Route path="/m08" element={<Page><Delivered /></Page>} />
                <Route path="/m09" element={<Page><Failed /></Page>} />
                <Route path="/m11" element={<Page><Settings /></Page>} />
                <Route path="/m12" element={<Page><Reconnect /></Page>} />
                <Route path="/m13" element={<Page><Disconnected /></Page>} />
                <Route path="/components" element={<Page><Components /></Page>} />
              </Routes>
            </motion.div>
          </AnimatePresence>
        </div>
      </main>
    </div>
  )
}
