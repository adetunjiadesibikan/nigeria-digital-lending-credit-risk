-- ============================================================
-- Nigeria Digital Lending Credit Risk Intelligence
-- Author: Adetunji Adesibikan
-- Tool: DB Browser for SQLite
-- Dataset: Nigeria_Digital_Lending.db
--
-- Context: Synthetic dataset modelling a Nigerian digital
-- lender's loan portfolio — 500 applications, 239 disbursed
-- loans across 4 products and 8 states. Dataset structure
-- reflects real Nigerian digital lending product design,
-- CBN regulatory thresholds (5% NPL prudential guideline),
-- and IFRS 9 credit classification logic.
-- Answers portfolio monitoring questions that credit risk
-- teams at Moniepoint, FairMoney, Carbon and Nigerian
-- commercial banks manage daily.
-- ============================================================


/* Q1: Application Funnel Analysis — approval rates by credit score band */
SELECT	credit_score_band,
		COUNT(*) AS total_applications,
		SUM(CASE WHEN approval_status = 'Approved' THEN 1 ELSE 0 END) AS approved_applications,
		SUM(CASE WHEN approval_status = 'Declined' THEN 1 ELSE 0 END) AS declined_applications,
		ROUND(SUM(CASE WHEN approval_status = 'Approved' THEN 1 ELSE 0 END)
			  * 100.0 / COUNT(*), 1) AS approval_rate_pct,
		ROUND(SUM(CASE WHEN approval_status = 'Approved' THEN 1 ELSE 0 END)
			  * 100.0 / NULLIF(SUM(CASE WHEN approval_status IN ('Approved','Declined')
								   THEN 1 ELSE 0 END), 0), 1) AS approval_rate_decided_pct
FROM	Loan_Applications
GROUP BY	credit_score_band
ORDER BY	credit_score_band;


/* Q2: Portfolio at Risk (Overall) — PAR30, PAR60, PAR90 on total loan book */
SELECT	SUM(loan_amount) AS total_portfolio,
		ROUND(SUM(CASE WHEN days_past_due >= 30 THEN loan_amount ELSE 0 END)
			  * 100.0 / SUM(loan_amount), 1) AS PAR30,
		ROUND(SUM(CASE WHEN days_past_due >= 60 THEN loan_amount ELSE 0 END)
			  * 100.0 / SUM(loan_amount), 1) AS PAR60,
		ROUND(SUM(CASE WHEN days_past_due >= 90 OR repayment_status = 'Written Off'
					   THEN loan_amount ELSE 0 END)
			  * 100.0 / SUM(loan_amount), 1) AS PAR90
FROM	Loan_Performance;


/* Q3: PAR by Loan Product — which product carries the highest delinquency? */
SELECT	la.loan_product,
		SUM(lp.loan_amount) AS total_portfolio,
		ROUND(SUM(CASE WHEN lp.days_past_due >= 30 THEN lp.loan_amount ELSE 0 END)
			  * 100.0 / SUM(lp.loan_amount), 1) AS PAR30,
		ROUND(SUM(CASE WHEN lp.days_past_due >= 60 THEN lp.loan_amount ELSE 0 END)
			  * 100.0 / SUM(lp.loan_amount), 1) AS PAR60,
		ROUND(SUM(CASE WHEN lp.days_past_due >= 90 OR lp.repayment_status = 'Written Off'
					   THEN lp.loan_amount ELSE 0 END)
			  * 100.0 / SUM(lp.loan_amount), 1) AS PAR90
FROM	Loan_Applications AS la
JOIN	Loan_Performance AS lp ON la.loan_id = lp.loan_id
GROUP BY	la.loan_product
ORDER BY	PAR30 DESC;


/* Q4: Default Rate Analysis — write-off rate vs NPL rate by product */
SELECT	la.loan_product,
		COUNT(*) AS total_loans,
		SUM(CASE WHEN lp.repayment_status = 'Written Off' THEN 1 ELSE 0 END) AS written_off_loans,
		ROUND(SUM(CASE WHEN lp.repayment_status = 'Written Off' THEN 1 ELSE 0 END)
			  * 100.0 / COUNT(*), 1) AS write_off_rate_pct,
		SUM(CASE WHEN lp.repayment_status IN ('90+ DPD','Written Off') THEN 1 ELSE 0 END) AS npl_loans,
		ROUND(SUM(CASE WHEN lp.repayment_status IN ('90+ DPD','Written Off') THEN 1 ELSE 0 END)
			  * 100.0 / COUNT(*), 1) AS npl_rate_pct
FROM	Loan_Applications AS la
JOIN	Loan_Performance AS lp ON la.loan_id = lp.loan_id
GROUP BY	la.loan_product
ORDER BY	npl_rate_pct DESC;


/* Q5: Interest Income and Profitability — expected vs cash collected vs confirmed realized */
SELECT	la.loan_product,
		COUNT(*) AS loans_disbursed,
		SUM(la.loan_amount) AS total_disbursed,
		SUM(lp.total_repayment_due - la.loan_amount) AS interest_expected,
		SUM(CASE WHEN lp.amount_repaid > la.loan_amount
				 THEN lp.amount_repaid - la.loan_amount ELSE 0 END) AS interest_cash_collected,
		SUM(CASE WHEN lp.repayment_status = 'Fully Repaid'
				 THEN lp.total_repayment_due - la.loan_amount ELSE 0 END) AS interest_realized,
		ROUND(SUM(CASE WHEN lp.repayment_status = 'Fully Repaid'
					   THEN lp.total_repayment_due - la.loan_amount ELSE 0 END)
			  * 100.0 / NULLIF(SUM(lp.total_repayment_due - la.loan_amount), 0), 1)
			  AS realization_rate_pct
FROM	Loan_Applications AS la
JOIN	Loan_Performance AS lp ON la.loan_id = lp.loan_id
GROUP BY	la.loan_product;


/* Q6: Geographic Credit Risk — where is exposure concentrated and repayment worst? */
SELECT	la.state,
		COUNT(*) AS loans,
		SUM(la.loan_amount) AS total_exposure,
		ROUND(AVG(la.loan_amount), 1) AS avg_loan,
		ROUND(SUM(CASE WHEN lp.repayment_status = 'Written Off' THEN 1 ELSE 0 END)
			  * 100.0 / COUNT(*), 1) AS default_rate_pct,
		ROUND(SUM(CASE WHEN lp.repayment_status IN ('90+ DPD','Written Off') THEN 1 ELSE 0 END)
			  * 100.0 / COUNT(*), 1) AS severe_delinquency_pct
FROM	Loan_Applications AS la
JOIN	Loan_Performance AS lp ON la.loan_id = lp.loan_id
GROUP BY	la.state
ORDER BY	default_rate_pct DESC;


/* Q7: Decline Reason Analysis — what is driving the most underwriting rejections? */
SELECT	decline_reason,
		COUNT(*) AS count,
		COUNT(*) * 100.0 / (SELECT COUNT(*) FROM Loan_Applications
							 WHERE approval_status = 'Declined') AS declined_pct
FROM	Loan_Applications
WHERE	approval_status = 'Declined'
GROUP BY	decline_reason;


/* Q8: Missed Opportunities — creditworthy borrowers incorrectly declined */
SELECT	decline_reason,
		COUNT(*) AS good_borrowers_rejected
FROM	Loan_Applications
WHERE	approval_status = 'Declined'
  AND	credit_score_band IN ('A','B')
  AND	debt_to_income_ratio < 40
GROUP BY	decline_reason
ORDER BY	good_borrowers_rejected DESC;


/* Q9: Early Warning Stress Matrix — forward-looking pre-default risk by DTI band and credit band */
SELECT
		CASE
			WHEN la.debt_to_income_ratio >= 50 THEN 'High DTI (50%+)'
			WHEN la.debt_to_income_ratio >= 40 THEN 'Elevated DTI (40-50%)'
			ELSE 'Acceptable DTI (Below 40%)'
		END AS dti_band,
		la.credit_score_band,
		COUNT(*) AS total_loans,
		SUM(CASE WHEN lp.number_of_late_payments >= 2
				 AND lp.repayment_status NOT IN ('90+ DPD','Written Off')
				 THEN 1 ELSE 0 END) AS stress_signals,
		ROUND(SUM(CASE WHEN lp.number_of_late_payments >= 2
					   AND lp.repayment_status NOT IN ('90+ DPD','Written Off')
					   THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS stress_signal_rate_pct,
		SUM(CASE WHEN lp.repayment_status IN ('30 DPD','60 DPD') THEN 1 ELSE 0 END) AS early_delinquency,
		ROUND(SUM(CASE WHEN lp.repayment_status IN ('30 DPD','60 DPD') THEN 1 ELSE 0 END)
			  * 100.0 / COUNT(*), 1) AS early_delinquency_rate_pct,
		SUM(CASE WHEN lp.repayment_status IN ('90+ DPD','Written Off') THEN 1 ELSE 0 END) AS confirmed_defaults,
		ROUND(SUM(CASE WHEN lp.repayment_status IN ('90+ DPD','Written Off') THEN 1 ELSE 0 END)
			  * 100.0 / COUNT(*), 1) AS default_rate_pct
FROM	Loan_Applications AS la
JOIN	Loan_Performance AS lp ON la.loan_id = lp.loan_id
GROUP BY	dti_band,
			la.credit_score_band
ORDER BY	default_rate_pct DESC;
