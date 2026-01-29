import { useState } from 'react'
import { useQuery } from 'convex/react'
import { api } from '../convex/_generated/api'

interface CalendarDay {
  date: Date
  isCurrentMonth: boolean
  hasMeditation: boolean
}

export function Calendar() {
  const [currentDate, setCurrentDate] = useState(new Date())

  // Fetch all meditation sessions
  const sessions = useQuery(api.meditationSessions.listMeditationSessions, {})

  if (sessions === undefined) {
    return <div className="loading">Loading calendar...</div>
  }

  // Convert sessions to a Set of date strings (YYYY-MM-DD) for quick lookup
  const meditationDates = new Set(
    sessions.map(session => {
      const date = new Date(session.completedAt)
      return date.toISOString().split('T')[0]
    })
  )

  // Get calendar grid for current month
  const year = currentDate.getFullYear()
  const month = currentDate.getMonth()

  const firstDayOfMonth = new Date(year, month, 1)
  const lastDayOfMonth = new Date(year, month + 1, 0)
  const firstDayOfWeek = firstDayOfMonth.getDay() // 0 = Sunday
  const daysInMonth = lastDayOfMonth.getDate()

  // Build calendar grid including days from previous/next months
  const calendarDays: CalendarDay[] = []

  // Add days from previous month to fill the first week
  const prevMonthLastDay = new Date(year, month, 0).getDate()
  for (let i = firstDayOfWeek - 1; i >= 0; i--) {
    const date = new Date(year, month - 1, prevMonthLastDay - i)
    calendarDays.push({
      date,
      isCurrentMonth: false,
      hasMeditation: meditationDates.has(date.toISOString().split('T')[0])
    })
  }

  // Add days of current month
  for (let day = 1; day <= daysInMonth; day++) {
    const date = new Date(year, month, day)
    calendarDays.push({
      date,
      isCurrentMonth: true,
      hasMeditation: meditationDates.has(date.toISOString().split('T')[0])
    })
  }

  // Add days from next month to complete the grid
  const remainingDays = 42 - calendarDays.length // 6 rows × 7 days
  for (let day = 1; day <= remainingDays; day++) {
    const date = new Date(year, month + 1, day)
    calendarDays.push({
      date,
      isCurrentMonth: false,
      hasMeditation: meditationDates.has(date.toISOString().split('T')[0])
    })
  }

  // Calculate current streak
  const calculateStreak = (): number => {
    let streak = 0
    const today = new Date()
    today.setHours(0, 0, 0, 0)

    let checkDate = new Date(today)

    while (true) {
      const dateStr = checkDate.toISOString().split('T')[0]
      if (meditationDates.has(dateStr)) {
        streak++
        checkDate.setDate(checkDate.getDate() - 1)
      } else {
        // If today doesn't have a meditation, streak is 0
        // If we're checking past days and hit a gap, stop
        break
      }
    }

    return streak
  }

  // Calculate 75% compliance for current year
  const calculateYearlyCompliance = (): { percentage: number; meditationDays: number; totalDays: number } => {
    const yearStart = new Date(new Date().getFullYear(), 0, 1)
    const today = new Date()
    today.setHours(23, 59, 59, 999)

    const daysSinceYearStart = Math.floor((today.getTime() - yearStart.getTime()) / (1000 * 60 * 60 * 24)) + 1

    // Count meditation days in current year
    const meditationDaysThisYear = sessions.filter(session => {
      const sessionDate = new Date(session.completedAt)
      return sessionDate.getFullYear() === new Date().getFullYear()
    }).length

    const percentage = (meditationDaysThisYear / daysSinceYearStart) * 100

    return {
      percentage: Math.round(percentage),
      meditationDays: meditationDaysThisYear,
      totalDays: daysSinceYearStart
    }
  }

  const streak = calculateStreak()
  const compliance = calculateYearlyCompliance()

  const goToPreviousMonth = () => {
    setCurrentDate(new Date(year, month - 1, 1))
  }

  const goToNextMonth = () => {
    setCurrentDate(new Date(year, month + 1, 1))
  }

  const goToToday = () => {
    setCurrentDate(new Date())
  }

  const monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ]

  const weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']

  return (
    <div className="calendar-container">
      <div className="calendar-stats">
        <div className="stat-card">
          <div className="stat-label">Current Streak</div>
          <div className="stat-value" data-testid="current-streak">{streak} days</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Year Progress</div>
          <div className="stat-value" data-testid="year-compliance">
            {compliance.percentage}% ({compliance.meditationDays}/{compliance.totalDays} days)
          </div>
          {compliance.percentage >= 75 && (
            <div className="compliance-badge" data-testid="compliance-badge">🎯 On track for 75% goal!</div>
          )}
          {compliance.percentage < 75 && (
            <div className="compliance-warning" data-testid="compliance-warning">
              📊 {75 - compliance.percentage}% below 75% goal
            </div>
          )}
        </div>
      </div>

      <div className="calendar-header">
        <button onClick={goToPreviousMonth} className="btn btn-secondary btn-sm" data-testid="prev-month">
          ← Previous
        </button>
        <h3 className="calendar-month" data-testid="calendar-month">
          {monthNames[month]} {year}
        </h3>
        <button onClick={goToNextMonth} className="btn btn-secondary btn-sm" data-testid="next-month">
          Next →
        </button>
      </div>

      <button onClick={goToToday} className="btn btn-primary btn-sm calendar-today-btn" data-testid="today-button">
        Today
      </button>

      <div className="calendar-grid">
        {weekDays.map(day => (
          <div key={day} className="calendar-weekday">
            {day}
          </div>
        ))}
        {calendarDays.map((day, index) => (
          <div
            key={index}
            className={`calendar-day ${
              !day.isCurrentMonth ? 'other-month' : ''
            } ${
              day.hasMeditation ? 'has-meditation' : ''
            } ${
              day.date.toDateString() === new Date().toDateString() ? 'today' : ''
            }`}
            data-testid={`calendar-day-${day.date.toISOString().split('T')[0]}`}
          >
            <span className="day-number">{day.date.getDate()}</span>
            {day.hasMeditation && <span className="meditation-indicator">✓</span>}
          </div>
        ))}
      </div>
    </div>
  )
}
