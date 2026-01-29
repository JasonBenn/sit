import { useState, useEffect } from 'react'
import { useQuery, useMutation } from 'convex/react'
import { api } from '../convex/_generated/api'
import type { Id } from '../convex/_generated/dataModel'
import { Calendar } from './Calendar'
import { ViewStats } from './ViewStats'

function App() {
  const [newBeliefText, setNewBeliefText] = useState('')
  const [editingId, setEditingId] = useState<Id<'beliefs'> | null>(null)
  const [editText, setEditText] = useState('')

  const [newPresetDuration, setNewPresetDuration] = useState('')
  const [newPresetLabel, setNewPresetLabel] = useState('')

  const [promptsPerDay, setPromptsPerDay] = useState('')
  const [wakingHourStart, setWakingHourStart] = useState('')
  const [wakingHourEnd, setWakingHourEnd] = useState('')

  const beliefs = useQuery(api.beliefs.listBeliefs)
  const createBelief = useMutation(api.beliefs.createBelief)
  const updateBelief = useMutation(api.beliefs.updateBelief)
  const deleteBelief = useMutation(api.beliefs.deleteBelief)

  const timerPresets = useQuery(api.timerPresets.listTimerPresets)
  const createTimerPreset = useMutation(api.timerPresets.createTimerPreset)
  const deleteTimerPreset = useMutation(api.timerPresets.deleteTimerPreset)
  const updateTimerPresetOrder = useMutation(api.timerPresets.updateTimerPresetOrder)

  const promptSettings = useQuery(api.promptSettings.getPromptSettings)
  const updatePromptSettings = useMutation(api.promptSettings.updatePromptSettings)

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!newBeliefText.trim()) return

    await createBelief({ text: newBeliefText })
    setNewBeliefText('')
  }

  const handleStartEdit = (id: Id<'beliefs'>, text: string) => {
    setEditingId(id)
    setEditText(text)
  }

  const handleCancelEdit = () => {
    setEditingId(null)
    setEditText('')
  }

  const handleSaveEdit = async (id: Id<'beliefs'>) => {
    if (!editText.trim()) return

    await updateBelief({ id, text: editText })
    setEditingId(null)
    setEditText('')
  }

  const handleDelete = async (id: Id<'beliefs'>) => {
    if (confirm('Are you sure you want to delete this belief?')) {
      await deleteBelief({ id })
    }
  }

  const handleCreatePreset = async (e: React.FormEvent) => {
    e.preventDefault()
    const duration = parseFloat(newPresetDuration)
    if (isNaN(duration) || duration <= 0) return

    await createTimerPreset({
      durationMinutes: duration,
      label: newPresetLabel.trim() || undefined,
    })
    setNewPresetDuration('')
    setNewPresetLabel('')
  }

  const handleDeletePreset = async (id: Id<'timerPresets'>) => {
    if (confirm('Are you sure you want to delete this timer preset?')) {
      await deleteTimerPreset({ id })
    }
  }

  const handleMovePresetUp = async (index: number) => {
    if (!timerPresets || index === 0) return

    const newPresets = [...timerPresets]
    const temp = newPresets[index - 1]
    newPresets[index - 1] = newPresets[index]
    newPresets[index] = temp

    await updateTimerPresetOrder({
      presetOrders: newPresets.map((preset, i) => ({
        id: preset._id,
        order: i,
      })),
    })
  }

  const handleMovePresetDown = async (index: number) => {
    if (!timerPresets || index === timerPresets.length - 1) return

    const newPresets = [...timerPresets]
    const temp = newPresets[index + 1]
    newPresets[index + 1] = newPresets[index]
    newPresets[index] = temp

    await updateTimerPresetOrder({
      presetOrders: newPresets.map((preset, i) => ({
        id: preset._id,
        order: i,
      })),
    })
  }

  // Populate form fields when prompt settings load
  useEffect(() => {
    if (promptSettings) {
      setPromptsPerDay(promptSettings.promptsPerDay.toString())
      setWakingHourStart(promptSettings.wakingHourStart.toString())
      setWakingHourEnd(promptSettings.wakingHourEnd.toString())
    }
  }, [promptSettings])

  const handleUpdatePromptSettings = async (e: React.FormEvent) => {
    e.preventDefault()
    const ppd = parseInt(promptsPerDay)
    const start = parseInt(wakingHourStart)
    const end = parseInt(wakingHourEnd)

    if (isNaN(ppd) || ppd <= 0 || ppd > 100) return
    if (isNaN(start) || start < 0 || start > 23) return
    if (isNaN(end) || end < 0 || end > 23) return
    if (start >= end) return

    await updatePromptSettings({
      promptsPerDay: ppd,
      wakingHourStart: start,
      wakingHourEnd: end,
    })
  }

  if (beliefs === undefined || timerPresets === undefined) {
    return (
      <div className="container">
        <div className="loading">Loading...</div>
      </div>
    )
  }

  return (
    <div className="container">
      <h1>Sit - Meditation Tracker</h1>

      <section>
        <h2>Limiting Beliefs</h2>

        <form onSubmit={handleCreate} className="belief-form" data-testid="belief-form">
          <input
            type="text"
            className="belief-input"
            placeholder="Enter a limiting belief..."
            value={newBeliefText}
            onChange={(e) => setNewBeliefText(e.target.value)}
            data-testid="belief-input"
          />
          <button type="submit" className="btn btn-primary" data-testid="add-belief-button">
            Add Belief
          </button>
        </form>

        {beliefs.length === 0 ? (
          <div className="empty-state" data-testid="empty-state">
            No limiting beliefs yet. Add one above to get started.
          </div>
        ) : (
          <ul className="beliefs-list" data-testid="beliefs-list">
            {beliefs.map((belief) => (
              <li key={belief._id} className="belief-item" data-testid="belief-item">
                {editingId === belief._id ? (
                  <div className="belief-edit-form">
                    <input
                      type="text"
                      className="belief-input"
                      value={editText}
                      onChange={(e) => setEditText(e.target.value)}
                      data-testid={`edit-input-${belief._id}`}
                      autoFocus
                    />
                    <button
                      onClick={() => handleSaveEdit(belief._id)}
                      className="btn btn-success"
                      data-testid={`save-button-${belief._id}`}
                    >
                      Save
                    </button>
                    <button
                      onClick={handleCancelEdit}
                      className="btn btn-secondary"
                      data-testid={`cancel-button-${belief._id}`}
                    >
                      Cancel
                    </button>
                  </div>
                ) : (
                  <>
                    <span className="belief-text" data-testid={`belief-text-${belief._id}`}>
                      {belief.text}
                    </span>
                    <div className="belief-actions">
                      <button
                        onClick={() => handleStartEdit(belief._id, belief.text)}
                        className="btn btn-secondary"
                        data-testid={`edit-button-${belief._id}`}
                      >
                        Edit
                      </button>
                      <button
                        onClick={() => handleDelete(belief._id)}
                        className="btn btn-danger"
                        data-testid={`delete-button-${belief._id}`}
                      >
                        Delete
                      </button>
                    </div>
                  </>
                )}
              </li>
            ))}
          </ul>
        )}
      </section>

      <section>
        <h2>Timer Presets</h2>

        <form onSubmit={handleCreatePreset} className="preset-form" data-testid="preset-form">
          <input
            type="number"
            className="preset-input"
            placeholder="Duration (minutes)"
            value={newPresetDuration}
            onChange={(e) => setNewPresetDuration(e.target.value)}
            data-testid="preset-duration-input"
            step="0.1"
            min="0.1"
          />
          <input
            type="text"
            className="preset-input"
            placeholder="Label (optional)"
            value={newPresetLabel}
            onChange={(e) => setNewPresetLabel(e.target.value)}
            data-testid="preset-label-input"
          />
          <button type="submit" className="btn btn-primary" data-testid="add-preset-button">
            Add Preset
          </button>
        </form>

        {timerPresets.length === 0 ? (
          <div className="empty-state" data-testid="preset-empty-state">
            No timer presets yet. Add one above to get started.
          </div>
        ) : (
          <ul className="presets-list" data-testid="presets-list">
            {timerPresets.map((preset, index) => (
              <li key={preset._id} className="preset-item" data-testid="preset-item">
                <span className="preset-text" data-testid={`preset-text-${preset._id}`}>
                  {preset.durationMinutes} min
                  {preset.label && <span className="preset-label"> - {preset.label}</span>}
                </span>
                <div className="preset-actions">
                  <button
                    onClick={() => handleMovePresetUp(index)}
                    className="btn btn-secondary btn-sm"
                    disabled={index === 0}
                    data-testid={`move-up-button-${preset._id}`}
                    title="Move up"
                  >
                    ↑
                  </button>
                  <button
                    onClick={() => handleMovePresetDown(index)}
                    className="btn btn-secondary btn-sm"
                    disabled={index === timerPresets.length - 1}
                    data-testid={`move-down-button-${preset._id}`}
                    title="Move down"
                  >
                    ↓
                  </button>
                  <button
                    onClick={() => handleDeletePreset(preset._id)}
                    className="btn btn-danger"
                    data-testid={`delete-preset-button-${preset._id}`}
                  >
                    Delete
                  </button>
                </div>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section>
        <h2>Prompt Settings</h2>

        <form onSubmit={handleUpdatePromptSettings} className="prompt-settings-form" data-testid="prompt-settings-form">
          <div className="form-group">
            <label htmlFor="prompts-per-day">Prompts per day:</label>
            <input
              id="prompts-per-day"
              type="number"
              className="prompt-input"
              placeholder="e.g., 4"
              value={promptsPerDay}
              onChange={(e) => setPromptsPerDay(e.target.value)}
              data-testid="prompts-per-day-input"
              min="1"
              max="100"
            />
          </div>

          <div className="form-group">
            <label htmlFor="waking-hour-start">Waking hours start (0-23):</label>
            <input
              id="waking-hour-start"
              type="number"
              className="prompt-input"
              placeholder="e.g., 7"
              value={wakingHourStart}
              onChange={(e) => setWakingHourStart(e.target.value)}
              data-testid="waking-hour-start-input"
              min="0"
              max="23"
            />
          </div>

          <div className="form-group">
            <label htmlFor="waking-hour-end">Waking hours end (0-23):</label>
            <input
              id="waking-hour-end"
              type="number"
              className="prompt-input"
              placeholder="e.g., 22"
              value={wakingHourEnd}
              onChange={(e) => setWakingHourEnd(e.target.value)}
              data-testid="waking-hour-end-input"
              min="0"
              max="23"
            />
          </div>

          <button type="submit" className="btn btn-primary" data-testid="save-prompt-settings-button">
            Save Settings
          </button>
        </form>

        {promptSettings && (
          <div className="settings-display" data-testid="settings-display">
            <p>Current settings: {promptSettings.promptsPerDay} prompts per day, {promptSettings.wakingHourStart}:00 - {promptSettings.wakingHourEnd}:00</p>
          </div>
        )}
      </section>

      <section>
        <h2>Meditation Calendar</h2>
        <Calendar />
      </section>

      <section>
        <h2>View Statistics</h2>
        <ViewStats />
      </section>
    </div>
  )
}

export default App
