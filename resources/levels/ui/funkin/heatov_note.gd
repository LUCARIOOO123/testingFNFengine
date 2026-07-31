@tool
extends RubiconLevelNoteMetadata

func note_hit(result: RubiconLevelNoteHitResult) -> RubiconLevelNoteHitResult:
	match result.scoring_rating:
		RubiconLevelNoteHitResult.Judgment.JUDGMENT_MISS:
			result.scoring_health_delta = -20
		RubiconLevelNoteHitResult.Judgment.JUDGMENT_PERFECT:
			result.scoring_health_delta = 4
		_:
			result.scoring_health_delta = 1 + randi() % 2
	return result
