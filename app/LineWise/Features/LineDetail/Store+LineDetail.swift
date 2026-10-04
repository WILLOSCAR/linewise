import Foundation
import SwiftData

/// 线路页 / 记这一次 需要的额外写操作。都返回撤销闭包或直接落盘。
extension Store {
    func line(id: UUID) -> Line? {
        var d = FetchDescriptor<Line>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        return try? context.fetch(d).first
    }

    /// 改名 / 难度 / 主观难度。
    func updateLineDetails(_ line: Line, name: String, gradeText: String?, feltGrade: FeltGrade?) -> () -> Void {
        let previous = (line.name, line.gradeText, line.gradeSource, line.feltGrade)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty { line.name = trimmedName }
        let grade = gradeText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let newGrade = (grade?.isEmpty == false) ? grade : nil
        if newGrade != line.gradeText {
            line.gradeText = newGrade
            line.gradeSource = newGrade == nil ? nil : .manual
        }
        line.feltGrade = feltGrade
        line.updatedAt = .now
        save()
        return { [self] in
            line.name = previous.0
            line.gradeText = previous.1
            line.gradeSource = previous.2
            line.feltGrade = previous.3
            save()
        }
    }

    /// 墙区与角度（对这面墙上所有线生效）。
    func updateWallDetails(_ wall: Wall, areaName: String?, angle: WallAngle) -> () -> Void {
        let previous = (wall.areaName, wall.angle)
        let area = areaName?.trimmingCharacters(in: .whitespacesAndNewlines)
        wall.areaName = (area?.isEmpty == false) ? area : nil
        wall.angle = angle
        for line in wall.lines { line.updatedAt = .now }
        save()
        return { [self] in
            wall.areaName = previous.0
            wall.angle = previous.1
            save()
        }
    }

    /// 改提醒并返回撤销闭包（`updateReminder` 本身不返回）。
    func updateReminderUndoable(_ line: Line, text: String) -> () -> Void {
        let previous = (line.reminderText, line.reminderSessionID, line.reminderVerified)
        updateReminder(line, text: text)
        return { [self] in
            line.reminderText = previous.0
            line.reminderSessionID = previous.1
            line.reminderVerified = previous.2
            save()
        }
    }

    /// 把表单草稿写进记录（不保存；随后应调用 `commitSession`）。
    func write(_ draft: SessionDraft, to session: Session, date: Date) {
        let day = Calendar.current.startOfDay(for: date)
        if session.date != day { session.date = day }
        session.attemptCount = max(0, draft.attemptCount)
        session.sent = draft.sent
        session.fallHoldID = draft.fallHoldID
        session.fallStepIndex = draft.fallStepIndex
        session.reason = draft.reason
        let note = draft.trimmedNote
        session.note = note.isEmpty ? nil : note
        // 有点就不存文字版；没点（无照片线）才写 fallText。
        let fallText = draft.trimmedFallText
        session.fallText = (draft.fallHoldID == nil && !fallText.isEmpty) ? fallText : nil
        session.attempts = AttemptSync.resized(draft.attempts, to: draft.attempts.isEmpty ? 0 : session.attemptCount)
    }

    /// 写入并更新提醒：`fallLabel` 优先用点的编号，无照片线退回文字版。
    /// `reminder` 是表单里问过“有用吗”的那句提醒（没问为 nil）。验证必须在换提醒之前记下，
    /// 否则新记录一有内容，提醒就换成新的，对旧那句的验证也跟着丢了。
    func commit(_ draft: SessionDraft, to session: Session, line: Line, date: Date, checking reminder: String? = nil) {
        write(draft, to: session, date: date)
        if let reminder {
            session.check = draft.check
            session.reminderSnapshot = draft.check == nil ? nil : reminder
            if draft.check == .worked, line.reminderText == reminder { line.reminderVerified = true }
        }
        commitSession(session, line: line, fallLabel: line.label(for: session.fallHoldID) ?? session.fallText)
    }

    /// 合并进另一条记录后，把原记录彻底移除（不提供撤销：这一步是用户改日期的直接结果）。
    func removeSession(_ session: Session, from line: Line) {
        line.sessions.removeAll { $0.id == session.id }
        if line.reminderSessionID == session.id {
            line.reminderSessionID = nil
        }
        context.delete(session)
        save()
    }
}

extension SessionDraft {
    /// 从记录建草稿。旧数据把“掉在 …”编码在一句话开头，这里拆回 `fallText`（仅无照片线需要）。
    init(session: Session, decodeLegacyFall: Bool = false) {
        let resolved = decodeLegacyFall
            ? NoPhotoFall.resolve(fallText: session.fallText, note: session.note)
            : (fall: session.fallText ?? "", note: session.note ?? "")
        self.init(
            attemptCount: session.attemptCount,
            sent: session.sent,
            fallHoldID: session.fallHoldID,
            fallStepIndex: session.fallStepIndex,
            reason: session.reason,
            note: resolved.note,
            fallText: resolved.fall,
            attempts: session.attempts,
            check: session.check
        )
    }
}
