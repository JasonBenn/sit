import { useState } from 'react'
import { useQuery } from 'convex/react'
import { api } from '../convex/_generated/api'

interface DayStats {
  date: string // YYYY-MM-DD
  yesCount: number
  totalCount: number
  percentage: number
}

interface WeekStats {
  weekLabel: string
  startDate: string
  endDate: string
  yesCount: number
  totalCount: number
  percentage: number
}

interface MonthStats {
  monthLabel: string
  year: number
  month: number
  yesCount: number
  totalCount: number
  percentage: number
}

type TimeRange = 'daily' | 'weekly' | 'monthly'

export function ViewStats() {
  const [timeRange, setTimeRange] = useState<TimeRange>('daily')
  const [daysToShow, setDaysToShow] = useState(30)

  // Fetch all prompt responses
  const responses = useQuery(api.promptResponses.listPromptResponses, {})

  if (responses === undefined) {
    return <div className="loading">Loading View stats...</div>
  }

  // Calculate daily stats
  const calculateDailyStats = (): DayStats[] => {
    const dailyMap = new Map<string, { yes: number; total: number }>()

    responses.forEach(response => {
      const date = new Date(response.respondedAt)
      const dateStr = date.toISOString().split('T')[0]

      if (!dailyMap.has(dateStr)) {
        dailyMap.set(dateStr, { yes: 0, total: 0 })
      }

      const stats = dailyMap.get(dateStr)!
      stats.total++
      if (response.inTheView) {
        stats.yes++
      }
    })

    const dailyStats: DayStats[] = []
    dailyMap.forEach((stats, dateStr) => {
      dailyStats.push({
        date: dateStr,
        yesCount: stats.yes,
        totalCount: stats.total,
        percentage: stats.total > 0 ? Math.round((stats.yes / stats.total) * 100) : 0
      })
    })

    // Sort by date descending (most recent first)
    dailyStats.sort((a, b) => b.date.localeCompare(a.date))

    return dailyStats.slice(0, daysToShow)
  }

  // Calculate weekly stats
  const calculateWeeklyStats = (): WeekStats[] => {
    // Group by week (ISO week)
    const weekMap = new Map<string, { yes: number; total: number; dates: Date[] }>()

    responses.forEach(response => {
      const date = new Date(response.respondedAt)

      // Get the Monday of the week containing this date
      const dayOfWeek = date.getDay()
      const diff = date.getDate() - dayOfWeek + (dayOfWeek === 0 ? -6 : 1) // adjust when day is Sunday
      const monday = new Date(date)
      monday.setDate(diff)
      monday.setHours(0, 0, 0, 0)

      const weekKey = monday.toISOString().split('T')[0]

      if (!weekMap.has(weekKey)) {
        weekMap.set(weekKey, { yes: 0, total: 0, dates: [] })
      }

      const stats = weekMap.get(weekKey)!
      stats.total++
      stats.dates.push(date)
      if (response.inTheView) {
        stats.yes++
      }
    })

    const weeklyStats: WeekStats[] = []
    weekMap.forEach((stats, weekKey) => {
      const monday = new Date(weekKey)
      const sunday = new Date(monday)
      sunday.setDate(sunday.getDate() + 6)

      const formatDate = (d: Date) => {
        const month = d.getMonth() + 1
        const day = d.getDate()
        return `${month}/${day}`
      }

      weeklyStats.push({
        weekLabel: `Week of ${formatDate(monday)}`,
        startDate: monday.toISOString().split('T')[0],
        endDate: sunday.toISOString().split('T')[0],
        yesCount: stats.yes,
        totalCount: stats.total,
        percentage: stats.total > 0 ? Math.round((stats.yes / stats.total) * 100) : 0
      })
    })

    // Sort by start date descending
    weeklyStats.sort((a, b) => b.startDate.localeCompare(a.startDate))

    return weeklyStats.slice(0, 12) // Show last 12 weeks
  }

  // Calculate monthly stats
  const calculateMonthlyStats = (): MonthStats[] => {
    const monthMap = new Map<string, { yes: number; total: number }>()

    responses.forEach(response => {
      const date = new Date(response.respondedAt)
      const year = date.getFullYear()
      const month = date.getMonth()
      const monthKey = `${year}-${String(month + 1).padStart(2, '0')}`

      if (!monthMap.has(monthKey)) {
        monthMap.set(monthKey, { yes: 0, total: 0 })
      }

      const stats = monthMap.get(monthKey)!
      stats.total++
      if (response.inTheView) {
        stats.yes++
      }
    })

    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ]

    const monthlyStats: MonthStats[] = []
    monthMap.forEach((stats, monthKey) => {
      const [year, monthStr] = monthKey.split('-')
      const month = parseInt(monthStr) - 1

      monthlyStats.push({
        monthLabel: `${monthNames[month]} ${year}`,
        year: parseInt(year),
        month,
        yesCount: stats.yes,
        totalCount: stats.total,
        percentage: stats.total > 0 ? Math.round((stats.yes / stats.total) * 100) : 0
      })
    })

    // Sort by year/month descending
    monthlyStats.sort((a, b) => {
      if (a.year !== b.year) return b.year - a.year
      return b.month - a.month
    })

    return monthlyStats.slice(0, 12) // Show last 12 months
  }

  // Calculate overall stats
  const calculateOverallStats = () => {
    if (responses.length === 0) {
      return { percentage: 0, yesCount: 0, totalCount: 0 }
    }

    const yesCount = responses.filter(r => r.inTheView).length
    const totalCount = responses.length
    const percentage = Math.round((yesCount / totalCount) * 100)

    return { percentage, yesCount, totalCount }
  }

  const dailyStats = timeRange === 'daily' ? calculateDailyStats() : []
  const weeklyStats = timeRange === 'weekly' ? calculateWeeklyStats() : []
  const monthlyStats = timeRange === 'monthly' ? calculateMonthlyStats() : []
  const overallStats = calculateOverallStats()

  const formatDate = (dateStr: string) => {
    const date = new Date(dateStr)
    const month = date.getMonth() + 1
    const day = date.getDate()
    const year = date.getFullYear()
    return `${month}/${day}/${year}`
  }

  const getPercentageColor = (percentage: number) => {
    if (percentage >= 75) return '#4caf50'
    if (percentage >= 50) return '#ff9800'
    return '#f44336'
  }

  return (
    <div className="view-stats-container">
      <div className="stats-summary">
        <div className="stat-card">
          <div className="stat-label">Overall View %</div>
          <div
            className="stat-value"
            style={{ color: getPercentageColor(overallStats.percentage) }}
            data-testid="overall-percentage"
          >
            {overallStats.percentage}%
          </div>
          <div className="stat-detail" data-testid="overall-counts">
            {overallStats.yesCount} yes / {overallStats.totalCount} total
          </div>
        </div>
      </div>

      <div className="time-range-selector">
        <button
          className={`btn ${timeRange === 'daily' ? 'btn-primary' : 'btn-secondary'} btn-sm`}
          onClick={() => setTimeRange('daily')}
          data-testid="daily-button"
        >
          Daily
        </button>
        <button
          className={`btn ${timeRange === 'weekly' ? 'btn-primary' : 'btn-secondary'} btn-sm`}
          onClick={() => setTimeRange('weekly')}
          data-testid="weekly-button"
        >
          Weekly
        </button>
        <button
          className={`btn ${timeRange === 'monthly' ? 'btn-primary' : 'btn-secondary'} btn-sm`}
          onClick={() => setTimeRange('monthly')}
          data-testid="monthly-button"
        >
          Monthly
        </button>
      </div>

      {timeRange === 'daily' && (
        <div className="days-selector">
          <label htmlFor="days-to-show">Show last: </label>
          <select
            id="days-to-show"
            value={daysToShow}
            onChange={(e) => setDaysToShow(parseInt(e.target.value))}
            className="days-select"
            data-testid="days-select"
          >
            <option value={7}>7 days</option>
            <option value={14}>14 days</option>
            <option value={30}>30 days</option>
            <option value={60}>60 days</option>
            <option value={90}>90 days</option>
          </select>
        </div>
      )}

      {responses.length === 0 ? (
        <div className="empty-state" data-testid="empty-state">
          No prompt responses yet. View statistics will appear here once you start responding to prompts.
        </div>
      ) : (
        <div className="stats-table">
          {timeRange === 'daily' && (
            <table data-testid="daily-stats-table">
              <thead>
                <tr>
                  <th>Date</th>
                  <th>View %</th>
                  <th>Responses</th>
                </tr>
              </thead>
              <tbody>
                {dailyStats.map((stat) => (
                  <tr key={stat.date} data-testid={`daily-stat-${stat.date}`}>
                    <td>{formatDate(stat.date)}</td>
                    <td style={{ color: getPercentageColor(stat.percentage), fontWeight: 'bold' }}>
                      {stat.percentage}%
                    </td>
                    <td>{stat.yesCount}/{stat.totalCount}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}

          {timeRange === 'weekly' && (
            <table data-testid="weekly-stats-table">
              <thead>
                <tr>
                  <th>Week</th>
                  <th>View %</th>
                  <th>Responses</th>
                </tr>
              </thead>
              <tbody>
                {weeklyStats.map((stat) => (
                  <tr key={stat.startDate} data-testid={`weekly-stat-${stat.startDate}`}>
                    <td>{stat.weekLabel}</td>
                    <td style={{ color: getPercentageColor(stat.percentage), fontWeight: 'bold' }}>
                      {stat.percentage}%
                    </td>
                    <td>{stat.yesCount}/{stat.totalCount}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}

          {timeRange === 'monthly' && (
            <table data-testid="monthly-stats-table">
              <thead>
                <tr>
                  <th>Month</th>
                  <th>View %</th>
                  <th>Responses</th>
                </tr>
              </thead>
              <tbody>
                {monthlyStats.map((stat) => (
                  <tr key={`${stat.year}-${stat.month}`} data-testid={`monthly-stat-${stat.year}-${stat.month}`}>
                    <td>{stat.monthLabel}</td>
                    <td style={{ color: getPercentageColor(stat.percentage), fontWeight: 'bold' }}>
                      {stat.percentage}%
                    </td>
                    <td>{stat.yesCount}/{stat.totalCount}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}
    </div>
  )
}
