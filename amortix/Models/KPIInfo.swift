import SwiftUI

// MARK: - KPI Info catalog

struct KPIInfo: Identifiable {
    let id:             String
    let titleKey:       LocalizedStringKey
    let explanationKey: LocalizedStringKey
    let formulaKey:     LocalizedStringKey?
    let exampleKey:     LocalizedStringKey
}

extension KPIInfo {
    static let catalog: [String: KPIInfo] = [

        "monthly_payment": KPIInfo(
            id: "monthly_payment",
            titleKey:       "kpi_monthly_payment_title",
            explanationKey: "kpi_monthly_payment_explanation",
            formulaKey:     "kpi_monthly_payment_formula",
            exampleKey:     "kpi_monthly_payment_example"
        ),
        "mixed_fixed_payment": KPIInfo(
            id: "mixed_fixed_payment",
            titleKey:       "kpi_mixed_fixed_payment_title",
            explanationKey: "kpi_mixed_fixed_payment_explanation",
            formulaKey:     nil,
            exampleKey:     "kpi_mixed_fixed_payment_example"
        ),
        "mixed_variable_payment": KPIInfo(
            id: "mixed_variable_payment",
            titleKey:       "kpi_mixed_variable_payment_title",
            explanationKey: "kpi_mixed_variable_payment_explanation",
            formulaKey:     nil,
            exampleKey:     "kpi_mixed_variable_payment_example"
        ),
        "total_interest": KPIInfo(
            id: "total_interest",
            titleKey:       "kpi_total_interest_title",
            explanationKey: "kpi_total_interest_explanation",
            formulaKey:     nil,
            exampleKey:     "kpi_total_interest_example"
        ),
        "total_cost": KPIInfo(
            id: "total_cost",
            titleKey:       "kpi_total_cost_title",
            explanationKey: "kpi_total_cost_explanation",
            formulaKey:     nil,
            exampleKey:     "kpi_total_cost_example"
        ),
        "months_saved": KPIInfo(
            id: "months_saved",
            titleKey:       "kpi_months_saved_title",
            explanationKey: "kpi_months_saved_explanation",
            formulaKey:     "kpi_months_saved_formula",
            exampleKey:     "kpi_months_saved_example"
        ),
        "interest_saved": KPIInfo(
            id: "interest_saved",
            titleKey:       "kpi_interest_saved_title",
            explanationKey: "kpi_interest_saved_explanation",
            formulaKey:     nil,
            exampleKey:     "kpi_interest_saved_example"
        ),
        "net_saving": KPIInfo(
            id: "net_saving",
            titleKey:       "kpi_net_saving_title",
            explanationKey: "kpi_net_saving_explanation",
            formulaKey:     "kpi_net_saving_formula",
            exampleKey:     "kpi_net_saving_example"
        ),
        "commission": KPIInfo(
            id: "commission",
            titleKey:       "kpi_commission_title",
            explanationKey: "kpi_commission_explanation",
            formulaKey:     "kpi_commission_formula",
            exampleKey:     "kpi_commission_example"
        ),
        "new_payment": KPIInfo(
            id: "new_payment",
            titleKey:       "kpi_new_payment_title",
            explanationKey: "kpi_new_payment_explanation",
            formulaKey:     nil,
            exampleKey:     "kpi_new_payment_example"
        ),
        "euribor_diff_monthly": KPIInfo(
            id: "euribor_diff_monthly",
            titleKey:       "kpi_euribor_diff_monthly_title",
            explanationKey: "kpi_euribor_diff_monthly_explanation",
            formulaKey:     nil,
            exampleKey:     "kpi_euribor_diff_monthly_example"
        ),
        "amortize_saving": KPIInfo(
            id: "amortize_saving",
            titleKey:       "kpi_amortize_saving_title",
            explanationKey: "kpi_amortize_saving_explanation",
            formulaKey:     "kpi_amortize_saving_formula",
            exampleKey:     "kpi_amortize_saving_example"
        ),
        "invest_gain": KPIInfo(
            id: "invest_gain",
            titleKey:       "kpi_invest_gain_title",
            explanationKey: "kpi_invest_gain_explanation",
            formulaKey:     "kpi_invest_gain_formula",
            exampleKey:     "kpi_invest_gain_example"
        ),

        // MARK: - Input field info

        "input_capital": KPIInfo(
            id: "input_capital",
            titleKey:       "kpi_input_capital_title",
            explanationKey: "kpi_input_capital_explanation",
            formulaKey:     nil,
            exampleKey:     "kpi_input_capital_example"
        ),
        "input_years": KPIInfo(
            id: "input_years",
            titleKey:       "kpi_input_years_title",
            explanationKey: "kpi_input_years_explanation",
            formulaKey:     nil,
            exampleKey:     "kpi_input_years_example"
        ),
        "input_rate": KPIInfo(
            id: "input_rate",
            titleKey:       "kpi_input_rate_title",
            explanationKey: "kpi_input_rate_explanation",
            formulaKey:     nil,
            exampleKey:     "kpi_input_rate_example"
        ),
        "input_euribor": KPIInfo(
            id: "input_euribor",
            titleKey:       "kpi_input_euribor_title",
            explanationKey: "kpi_input_euribor_explanation",
            formulaKey:     nil,
            exampleKey:     "kpi_input_euribor_example"
        ),
        "input_spread": KPIInfo(
            id: "input_spread",
            titleKey:       "kpi_input_spread_title",
            explanationKey: "kpi_input_spread_explanation",
            formulaKey:     nil,
            exampleKey:     "kpi_input_spread_example"
        ),
        "input_remaining_capital": KPIInfo(
            id: "input_remaining_capital",
            titleKey:       "kpi_input_remaining_capital_title",
            explanationKey: "kpi_input_remaining_capital_explanation",
            formulaKey:     nil,
            exampleKey:     "kpi_input_remaining_capital_example"
        ),
        "input_months": KPIInfo(
            id: "input_months",
            titleKey:       "kpi_input_months_title",
            explanationKey: "kpi_input_months_explanation",
            formulaKey:     nil,
            exampleKey:     "kpi_input_months_example"
        ),
        "input_amortize_amount": KPIInfo(
            id: "input_amortize_amount",
            titleKey:       "kpi_input_amortize_amount_title",
            explanationKey: "kpi_input_amortize_amount_explanation",
            formulaKey:     nil,
            exampleKey:     "kpi_input_amortize_amount_example"
        ),
        "input_extra_monthly": KPIInfo(
            id: "input_extra_monthly",
            titleKey:       "kpi_input_extra_monthly_title",
            explanationKey: "kpi_input_extra_monthly_explanation",
            formulaKey:     nil,
            exampleKey:     "kpi_input_extra_monthly_example"
        ),
        "input_stress_rate": KPIInfo(
            id: "input_stress_rate",
            titleKey:       "kpi_input_stress_rate_title",
            explanationKey: "kpi_input_stress_rate_explanation",
            formulaKey:     nil,
            exampleKey:     "kpi_input_stress_rate_example"
        ),
        "input_euribor_delta": KPIInfo(
            id: "input_euribor_delta",
            titleKey:       "kpi_input_euribor_delta_title",
            explanationKey: "kpi_input_euribor_delta_explanation",
            formulaKey:     nil,
            exampleKey:     "kpi_input_euribor_delta_example"
        ),
    ]

    static func find(_ key: String) -> KPIInfo? { catalog[key] }
}
