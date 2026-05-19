from __future__ import annotations

from typing import Iterable

from app.models import (
    AICoverageResponse,
    AICoverageStatus,
    AIPantryCoveragePayload,
    AIShoppingGapsPayload,
    AIShoppingGapsResponse,
    AIValidationIssue,
    AIValidationResult,
)

_ALLOWED_UNITS = {
    "pcs",
    "g",
    "kg",
    "ml",
    "l",
    "tsp",
    "tbsp",
    "cup",
}


class AIPlanningValidationService:
    """Validates AI-generated planning payloads for integrity and consistency.

    Validation focuses on schema and consistency constraints only. It does not
    recompute coverage/gap decisions from scratch.
    """

    def validate_coverage_payload(self, payload: AIPantryCoveragePayload) -> AICoverageResponse:
        issues: list[AIValidationIssue] = []

        if not payload.ingredients:
            issues.append(
                AIValidationIssue(
                    code="coverage.empty_ingredients",
                    message="Coverage payload must include at least one ingredient.",
                    field_path="ingredients",
                )
            )

        self._validate_unique_names(
            names=(item.normalized_name for item in payload.ingredients),
            list_name="ingredients",
            issues=issues,
        )

        matched = 0
        missing = 0
        substituted = 0

        for index, item in enumerate(payload.ingredients):
            field_prefix = f"ingredients[{index}]"
            if not item.normalized_name.strip():
                issues.append(
                    AIValidationIssue(
                        code="coverage.empty_normalized_name",
                        message="normalized_name cannot be blank.",
                        field_path=f"{field_prefix}.normalized_name",
                    )
                )

            if item.required_unit.strip().lower() not in _ALLOWED_UNITS:
                issues.append(
                    AIValidationIssue(
                        code="coverage.unknown_required_unit",
                        message=f"Unsupported required_unit '{item.required_unit}'.",
                        field_path=f"{field_prefix}.required_unit",
                    )
                )

            if item.status == AICoverageStatus.available:
                matched += 1
                if item.missing_quantity > 0:
                    issues.append(
                        AIValidationIssue(
                            code="coverage.available_has_missing_qty",
                            message="Available ingredient cannot have missing_quantity > 0.",
                            field_path=f"{field_prefix}.missing_quantity",
                        )
                    )
            elif item.status == AICoverageStatus.missing:
                missing += 1
                if item.missing_quantity <= 0:
                    issues.append(
                        AIValidationIssue(
                            code="coverage.missing_without_missing_qty",
                            message="Missing ingredient must have missing_quantity > 0.",
                            field_path=f"{field_prefix}.missing_quantity",
                        )
                    )
            elif item.status == AICoverageStatus.substituted:
                substituted += 1
                if item.substitution is None:
                    issues.append(
                        AIValidationIssue(
                            code="coverage.substituted_without_substitution",
                            message="Substituted ingredient must include a substitution block.",
                            field_path=f"{field_prefix}.substitution",
                        )
                    )

            if item.available_quantity > item.required_quantity and item.status != AICoverageStatus.available:
                issues.append(
                    AIValidationIssue(
                        code="coverage.available_qty_inconsistent_status",
                        message="available_quantity > required_quantity conflicts with non-available status.",
                        field_path=f"{field_prefix}.available_quantity",
                    )
                )

        if payload.matched_count != matched:
            issues.append(
                AIValidationIssue(
                    code="coverage.summary_mismatch_matched",
                    message=f"matched_count {payload.matched_count} does not match derived value {matched}.",
                    field_path="matched_count",
                )
            )
        if payload.missing_count != missing:
            issues.append(
                AIValidationIssue(
                    code="coverage.summary_mismatch_missing",
                    message=f"missing_count {payload.missing_count} does not match derived value {missing}.",
                    field_path="missing_count",
                )
            )
        if payload.substituted_count != substituted:
            issues.append(
                AIValidationIssue(
                    code="coverage.summary_mismatch_substituted",
                    message=(
                        f"substituted_count {payload.substituted_count} "
                        f"does not match derived value {substituted}."
                    ),
                    field_path="substituted_count",
                )
            )

        total = len(payload.ingredients)
        expected_coverage = round(((matched + substituted) / total) * 100) if total > 0 else 0
        if payload.coverage_percent != expected_coverage:
            issues.append(
                AIValidationIssue(
                    code="coverage.summary_mismatch_percent",
                    message=(
                        f"coverage_percent {payload.coverage_percent} does not match "
                        f"derived value {expected_coverage}."
                    ),
                    field_path="coverage_percent",
                )
            )

        return AICoverageResponse(
            payload=payload,
            validation=AIValidationResult(valid=len(issues) == 0, issues=issues),
        )

    def validate_shopping_gaps_payload(
        self,
        payload: AIShoppingGapsPayload,
    ) -> AIShoppingGapsResponse:
        issues: list[AIValidationIssue] = []

        if payload.end_date < payload.start_date:
            issues.append(
                AIValidationIssue(
                    code="shopping.date_range_invalid",
                    message="end_date must be on or after start_date.",
                    field_path="end_date",
                )
            )

        if not payload.items:
            issues.append(
                AIValidationIssue(
                    code="shopping.empty_items",
                    message="Shopping gaps payload must include at least one item.",
                    field_path="items",
                )
            )

        self._validate_unique_names(
            names=(item.normalized_name for item in payload.items),
            list_name="items",
            issues=issues,
        )

        for index, item in enumerate(payload.items):
            field_prefix = f"items[{index}]"
            if not item.normalized_name.strip():
                issues.append(
                    AIValidationIssue(
                        code="shopping.empty_normalized_name",
                        message="normalized_name cannot be blank.",
                        field_path=f"{field_prefix}.normalized_name",
                    )
                )

            if item.suggested_unit.strip().lower() not in _ALLOWED_UNITS:
                issues.append(
                    AIValidationIssue(
                        code="shopping.unknown_suggested_unit",
                        message=f"Unsupported suggested_unit '{item.suggested_unit}'.",
                        field_path=f"{field_prefix}.suggested_unit",
                    )
                )

        return AIShoppingGapsResponse(
            payload=payload,
            validation=AIValidationResult(valid=len(issues) == 0, issues=issues),
        )

    def _validate_unique_names(
        self,
        *,
        names: Iterable[str],
        list_name: str,
        issues: list[AIValidationIssue],
    ) -> None:
        seen: set[str] = set()
        duplicates: set[str] = set()

        for raw_name in names:
            normalized = raw_name.strip().lower()
            if normalized in seen:
                duplicates.add(normalized)
            else:
                seen.add(normalized)

        for duplicate in sorted(duplicates):
            issues.append(
                AIValidationIssue(
                    code="common.duplicate_normalized_name",
                    message=f"Duplicate normalized_name '{duplicate}' found in {list_name}.",
                    field_path=list_name,
                )
            )
