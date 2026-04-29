"""Unit tests for DuplicateDetector — functions/services/duplicate_detector.py (F7.3)."""
from unittest.mock import MagicMock

from services.duplicate_detector import find_canonical


def _make_doc(doc_id: str, lat: float, lng: float) -> MagicMock:
    doc = MagicMock()
    doc.id = doc_id
    doc.to_dict.return_value = {
        "threat_type": "animal_muerto",
        "status": "pending_validation",
        "is_duplicate": False,
        "location": {"lat": lat, "lng": lng},
    }
    return doc


def _make_db(*candidates) -> MagicMock:
    """Build a mock Firestore DB that returns the given docs on .stream()."""
    db = MagicMock()
    query = MagicMock()
    query.where.return_value = query
    query.stream.return_value = iter(candidates)
    db.collection.return_value.where.return_value = query
    return db


def test_no_candidates_returns_none():
    """Empty stream → no canonical report found."""
    db = _make_db()
    result = find_canonical(db, "new-id", "animal_muerto", 20.0, -103.0)
    assert result is None


def test_candidate_within_100m_returns_its_id():
    """A report ≈50 m away (same type) should be returned as the canonical."""
    # ~0.0005° latitude ≈ 55 m
    close_doc = _make_doc("canon-id", 20.0005, -103.0)
    db = _make_db(close_doc)
    result = find_canonical(db, "new-id", "animal_muerto", 20.0, -103.0)
    assert result == "canon-id"


def test_candidate_beyond_100m_returns_none():
    """A report ≈222 m away should not be considered a duplicate."""
    # ~0.002° latitude ≈ 222 m
    far_doc = _make_doc("far-id", 20.002, -103.0)
    db = _make_db(far_doc)
    result = find_canonical(db, "new-id", "animal_muerto", 20.0, -103.0)
    assert result is None


def test_same_report_id_is_skipped():
    """The newly created report itself must not match itself as a canonical."""
    same_doc = _make_doc("new-id", 20.0005, -103.0)  # within 100 m, same id
    db = _make_db(same_doc)
    result = find_canonical(db, "new-id", "animal_muerto", 20.0, -103.0)
    assert result is None
