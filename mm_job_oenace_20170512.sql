
/*
############################################################################################
                               get all salary paymentrecords in previous month
############################################################################################
*/

DELETE
FROM da_twm_result_seg.lab_gehalt_1m T 
WHERE  EXISTS (
    SEL * FROM da_twm_result_seg.lab_gehalt_1m neu
    WHERE neu.INSTITUTSZUORDNUNG = T.INSTITUTSZUORDNUNG
    AND neu.KUNDENNUMMER = T.KUNDENNUMMER
	AND T.ende_beobachtung_datum = CURRENT_DATE - EXTRACT(DAY FROM CURRENT_DATE)+1
    );



INSERT INTO da_twm_result_seg.lab_gehalt_1m



SEL 
p.ende_beobachtung_datum,
a.kontonummer,
a.institutszuordnung,
b.kundennummer,
a.ls_kontonummer,
a.ls_name,
MAX(a.datum) AS datum_neue_zahlung,
COUNT(ls_kontonummer) AS count_salary_6m,
SUM(BETRAG_EUR) AS betrag_1m_sum
FROM vb_data.ldr_kto_umsatz a
CROSS JOIN (SEL MAX(ENDE_BEOBACHTUNG_DATUM) AS ende_beobachtung_datum FROM vm_acrm_reporting.DASHBOARD WHERE KUNDENBASIS = 5) p
JOIN vb_data.ext_kto_basis b
ON a.kontonummer = b.kontonummer
AND a.institutszuordnung= b.institutszuordnung
AND a.datum BETWEEN ADD_MONTHS(p.ende_beobachtung_datum, - 1) AND p.ende_beobachtung_datum -1 
AND a.datum BETWEEN b.datum_von AND b.datum_bis
WHERE(
COALESCE(TRIM(a.textzeile_1),'')||COALESCE(TRIM(a.textzeile_2),'')||COALESCE(TRIM(a.textzeile_3),'') LIKE ANY
('%gehalt%','%lohn%''%PV01%','%PV02%',
'%PV03%',
'%PV04%',
'%PV05%',
'%PV06%',
'%PV07%',
'%PV08%',
'%PV09%',
'%PV10%',
'%PV11%',
'%PV13%',
'%PENSION%',
'%Bezug%')

OR COALESCE(TRIM(a.verwendungszweck),'')||COALESCE(TRIM(a.kundendaten_1),'')||COALESCE(TRIM(a.kundendaten_2),'') LIKE ANY
('%gehalt%','%lohn%''%PV01%','%PV02%',
'%PV03%',
'%PV04%',
'%PV05%',
'%PV06%',
'%PV07%',
'%PV08%',
'%PV09%',
'%PV10%',
'%PV11%',
'%PV13%',
'%PENSION%',
'%Bezug%'))

AND a.umsatzart = 'G'
AND a.betrag >= 100
GROUP BY 1,2,3,4,5,6
;


/*############################################################################################
                               get all salary paymentrecords with specific keywords in previous month
############################################################################################
*/


INSERT INTO da_twm_result_seg.lab_gehalt_1m



SEL 
a.ende_beobachtung_datum,
a.kontonummer,
a.institutszuordnung,
a.kundennummer,
a.ls_kontonummer,
a.ls_name,
MAX(a.datum) AS datum_neue_zahlung,
COUNT(ls_kontonummer) AS count_salary_6m,
SUM(BETRAG_EUR) AS betrag_1m_sum

FROM
(
SEL a.*,c.*,p.ende_beobachtung_datum,b.kundennummer
,COUNT(*)OVER(PARTITION BY ls_name) AS anz_ls_name, /*anz identifizierter records*/
COUNT(*)OVER(PARTITION BY gs_name) AS anz_gs_name, /*anz records pro konto*/
AVG(betrag)OVER(PARTITION BY gs_name) AS ds_betrag_gs_name,
ROW_NUMBER() OVER(PARTITION BY ls_name ORDER BY a.kontonummer ASC)  AS ls_nr, /*als qualifizierer um textzeile zu sehen iso group by*/
COALESCE(TRIM(a.textzeile_1),'')||COALESCE(TRIM(a.textzeile_2),'')||COALESCE(TRIM(a.textzeile_3),'') AS textzeile_123, /*TEXTZEILE_1 1,2,3 zusammen*/
COALESCE(TRIM(a.verwendungszweck),'')||COALESCE(TRIM(a.kundendaten_1),'')||COALESCE(TRIM(a.kundendaten_2),'') AS kundendaten_123 /*verwendungszweck 1,2,3 zusammen*/
FROM vb_data.LDR_KTO_UMSATZ a
CROSS JOIN (SEL MAX(ENDE_BEOBACHTUNG_DATUM) AS ende_beobachtung_datum FROM vm_acrm_reporting.DASHBOARD WHERE KUNDENBASIS = 5) p

JOIN vb_data.ext_kto_basis b
ON a.kontonummer = b.kontonummer
AND a.institutszuordnung= b.institutszuordnung
AND a.datum BETWEEN ADD_MONTHS(p.ende_beobachtung_datum, - 1) AND p.ende_beobachtung_datum -1 
AND a.datum BETWEEN b.datum_von AND b.datum_bis

LEFT JOIN 
(SEL year_of_calendar,month_of_year ,month_of_calendar
,CASE WHEN LENGTH('0'||CAST(month_of_year AS VARCHAR(2))) =3 THEN SUBSTR('0'||CAST(month_of_year AS VARCHAR(2)),2,2) ELSE SUBSTR('0'||CAST(month_of_year AS VARCHAR(2)),1,2) END AS month_2dig

,CASE WHEN month_of_year = 01 THEN 'j_n'
WHEN month_of_year = 1 THEN 'j_n'
WHEN month_of_year = 2 THEN 'feb'
WHEN month_of_year = 3 THEN 'm_r'
WHEN month_of_year = 4 THEN 'apr'
WHEN month_of_year = 5 THEN 'mai'
WHEN month_of_year = 6 THEN 'jun'
WHEN month_of_year = 7 THEN 'jul'
WHEN month_of_year = 8 THEN 'aug'
WHEN month_of_year = 9 THEN 'sep'
WHEN month_of_year = 10 THEN 'okt'
WHEN month_of_year = 11 THEN 'nov'
WHEN month_of_year = 12 THEN 'dez'
ELSE NULL END AS monat_text
FROM
sys_calendar.CALENDAR c 
GROUP BY 1,2,3,4,5
)c
ON  c.month_of_calendar  BETWEEN   c.month_of_calendar - c.month_of_year +EXTRACT(MONTH FROM a.datum) AND  c.month_of_calendar - c.month_of_year +EXTRACT(MONTH FROM ADD_MONTHS(a.datum, +2))
AND  c.year_of_calendar BETWEEN   EXTRACT(YEAR FROM a.datum) AND EXTRACT(YEAR FROM ADD_MONTHS(a.datum, + 2))

WHERE UMSATZART = 'G'
AND betrag BETWEEN 300 AND 3000
AND textzeile_123 NOT LIKE '%gehalt%'
AND textzeile_123 NOT LIKE '%lohn%'
AND textzeile_123 NOT LIKE '%reisekostenabrechnung%'
AND 
			(
			textzeile_123 LIKE '%abrechnung%'
			 AND 
						 	(		textzeile_123 LIKE '%'||TRIM(year_of_calendar||month_2dig)||'%' /* jahrMonat*/
						 OR
						 		(textzeile_123 LIKE TRIM('%'||TRIM(year_of_calendar)||'%') AND textzeile_123 LIKE TRIM('%'||TRIM(month_2dig)||'%')) /*jahr, Monat*/
						 OR
						 		(textzeile_123 LIKE TRIM('%'||monat_text||'%')) /*monat text*/
						  OR
						 		(textzeile_123 LIKE TRIM('%'||SUBSTR(CAST(year_of_calendar AS CHAR(4)),3,2)||'%') AND textzeile_123 LIKE TRIM('%'||TRIM(month_2dig)||'%')) /*jahr 2stellig, monat 2 stellig*/
						 )
 OR
			(
			 textzeile_123 LIKE '%abrechnung%'
			 AND 
						 (		kundendaten_123 LIKE '%'||TRIM(year_of_calendar||month_2dig)||'%' /* jahrMonat*/
						 
						 OR
						 		(kundendaten_123 LIKE TRIM('%'||TRIM(year_of_calendar)||'%') AND kundendaten_123 LIKE TRIM('%'||TRIM(month_2dig)||'%')) /*jahr, Monat*/
						 OR
						 		(kundendaten_123 LIKE TRIM('%'||monat_text||'%')) /*monat text*/
						 OR
						 		(kundendaten_123 LIKE TRIM('%'||SUBSTR(CAST(year_of_calendar AS CHAR(4)),3,2)||'%') AND kundendaten_123 LIKE TRIM('%'||TRIM(month_2dig)||'%')) /*jahr 2stellig, monat 2 stellig*/
						 )
			 )
 )
 
QUALIFY anz_gs_name < 12
AND anz_ls_name > 10
)a 
GROUP BY 1,2,3,4,5,6;



/*
############################################################################################
                               GET ALL salary paymentrecords OF previous 6 months PRIOR TO previous MONTH
############################################################################################

*/


DELETE
FROM da_twm_result_seg.lab_gehalt_6m T 
WHERE  EXISTS (
    SEL * FROM da_twm_result_seg.lab_gehalt_6m neu
    WHERE neu.INSTITUTSZUORDNUNG = T.INSTITUTSZUORDNUNG
    AND neu.KUNDENNUMMER = T.KUNDENNUMMER
	AND T.ende_beobachtung_datum = CURRENT_DATE - EXTRACT(DAY FROM CURRENT_DATE)+1
    )
;

INSERT INTO da_twm_result_seg.lab_gehalt_6m
SEL a.ende_beobachtung_datum
,a.kontonummer
,a.institutszuordnung
,a.kundennummer
,a.ls_kontonummer
,a.ls_name
,a.datum_letzte_alte_zahlung
,a.count_salary_6m
,a.betrag_6m_ds
FROM
(
SEL a.ende_beobachtung_datum
,a.kontonummer
,a.institutszuordnung
,a.kundennummer
,a.ls_kontonummer
,a.ls_name
,a.datum_letzte_alte_zahlung
,a.count_salary_6m
,a.betrag_6m_ds
FROM
(
SEL 
p.ende_beobachtung_datum,
a.kontonummer,
a.institutszuordnung,
b.kundennummer,
a.ls_kontonummer,
a.ls_name,
MAX(a.datum) AS datum_letzte_alte_zahlung,
COUNT(ls_kontonummer) AS count_salary_6m,
SUM(BETRAG_EUR)/count_salary_6m AS Betrag_6m_ds

FROM vb_data.ldr_kto_umsatz a
CROSS JOIN (SEL MAX(ENDE_BEOBACHTUNG_DATUM) AS ende_beobachtung_datum FROM vm_acrm_reporting.DASHBOARD WHERE KUNDENBASIS = 5) p

JOIN vb_data.ext_kto_basis b
ON a.kontonummer = b.kontonummer
AND a.institutszuordnung= b.institutszuordnung
AND a.datum BETWEEN ADD_MONTHS(p.ende_beobachtung_datum, - 7) AND ADD_MONTHS(p.ende_beobachtung_datum -1, - 1)
AND a.datum BETWEEN b.datum_von AND b.datum_bis
WHERE(
COALESCE(TRIM(a.textzeile_1),'')||COALESCE(TRIM(a.textzeile_2),'')||COALESCE(TRIM(a.textzeile_3),'') LIKE ANY
('%gehalt%','%lohn%''%PV01%','%PV02%',
'%PV03%',
'%PV04%',
'%PV05%',
'%PV06%',
'%PV07%',
'%PV08%',
'%PV09%',
'%PV10%',
'%PV11%',
'%PV13%',
'%PENSION%',
'%Bezug%')

OR COALESCE(TRIM(a.verwendungszweck),'')||COALESCE(TRIM(a.kundendaten_1),'')||COALESCE(TRIM(a.kundendaten_2),'') LIKE ANY
('%gehalt%','%lohn%''%PV01%','%PV02%',
'%PV03%',
'%PV04%',
'%PV05%',
'%PV06%',
'%PV07%',
'%PV08%',
'%PV09%',
'%PV10%',
'%PV11%',
'%PV13%',
'%PENSION%',
'%Bezug%'))


AND a.umsatzart = 'G'
AND a.betrag >= 100
GROUP BY 1,2,3,4,5,6
HAVING count_salary_6m >=1
)a QUALIFY ROW_NUMBER() OVER (PARTITION BY a.ende_beobachtung_datum
,a.kontonummer
,a.institutszuordnung
,a.kundennummer
,a.ls_kontonummer ORDER BY a.datum_letzte_alte_zahlung DESC) = 1
)a QUALIFY ROW_NUMBER() OVER (PARTITION BY a.ende_beobachtung_datum
,a.kontonummer
,a.institutszuordnung
,a.kundennummer
,a.ls_name ORDER BY a.datum_letzte_alte_zahlung DESC) = 1;

/*
############################################################################################
                               GET ALL salary paymentrecords OF previous 6 months PRIOR TO previous MONTH with specific keywords
############################################################################################

*/

INSERT INTO da_twm_result_seg.lab_gehalt_6m

SEL a.ende_beobachtung_datum
,a.kontonummer
,a.institutszuordnung
,a.kundennummer
,a.ls_kontonummer
,a.ls_name
,a.datum_letzte_alte_zahlung
,a.count_salary_6m
,a.betrag_6m_ds

FROM
(
SEL a.ende_beobachtung_datum
,a.kontonummer
,a.institutszuordnung
,a.kundennummer
,a.ls_kontonummer
,a.ls_name
,a.datum_letzte_alte_zahlung
,a.count_salary_6m
,a.betrag_6m_ds
FROM

(

SEL 
a.ende_beobachtung_datum,
a.kontonummer,
a.institutszuordnung,
a.kundennummer,
a.ls_kontonummer,
a.ls_name,
MAX(a.datum) AS datum_letzte_alte_zahlung,
COUNT(a.ls_kontonummer) AS count_salary_6m,
SUM(a.BETRAG_EUR)/count_salary_6m AS Betrag_6m_ds
FROM
(
SEL
a.*,c.*,p.ende_beobachtung_datum,b.kundennummer
,COUNT(*)OVER(PARTITION BY ls_name) AS anz_ls_name, /*anz identifizierter records*/
COUNT(*)OVER(PARTITION BY gs_name) AS anz_gs_name, /*anz records pro konto*/
AVG(betrag)OVER(PARTITION BY gs_name) AS ds_betrag_gs_name,
ROW_NUMBER() OVER(PARTITION BY ls_name ORDER BY a.kontonummer ASC)  AS ls_nr, /*als qualifizierer um textzeile zu sehen iso group by*/
COALESCE(TRIM(a.textzeile_1),'')||COALESCE(TRIM(a.textzeile_2),'')||COALESCE(TRIM(a.textzeile_3),'') AS textzeile_123, /*TEXTZEILE_1 1,2,3 zusammen*/
COALESCE(TRIM(a.verwendungszweck),'')||COALESCE(TRIM(a.kundendaten_1),'')||COALESCE(TRIM(a.kundendaten_2),'') AS kundendaten_123 /*verwendungszweck 1,2,3 zusammen*/
FROM vb_data.LDR_KTO_UMSATZ a
CROSS JOIN (SEL MAX(ENDE_BEOBACHTUNG_DATUM) AS ende_beobachtung_datum FROM vm_acrm_reporting.DASHBOARD WHERE KUNDENBASIS = 5) p

JOIN vb_data.ext_kto_basis b
ON a.kontonummer = b.kontonummer
AND a.institutszuordnung= b.institutszuordnung
AND a.datum BETWEEN ADD_MONTHS(p.ende_beobachtung_datum, - 7) AND ADD_MONTHS(p.ende_beobachtung_datum -1, - 1)
AND a.datum BETWEEN b.datum_von AND b.datum_bis


LEFT JOIN 
(SEL year_of_calendar,month_of_year ,month_of_calendar
,CASE WHEN LENGTH('0'||CAST(month_of_year AS VARCHAR(2))) =3 THEN SUBSTR('0'||CAST(month_of_year AS VARCHAR(2)),2,2) ELSE SUBSTR('0'||CAST(month_of_year AS VARCHAR(2)),1,2) END AS month_2dig

,CASE WHEN month_of_year = 01 THEN 'j_n'
WHEN month_of_year = 1 THEN 'j_n'
WHEN month_of_year = 2 THEN 'feb'
WHEN month_of_year = 3 THEN 'm_r'
WHEN month_of_year = 4 THEN 'apr'
WHEN month_of_year = 5 THEN 'mai'
WHEN month_of_year = 6 THEN 'jun'
WHEN month_of_year = 7 THEN 'jul'
WHEN month_of_year = 8 THEN 'aug'
WHEN month_of_year = 9 THEN 'sep'
WHEN month_of_year = 10 THEN 'okt'
WHEN month_of_year = 11 THEN 'nov'
WHEN month_of_year = 12 THEN 'dez'
ELSE NULL END AS monat_text
FROM
sys_calendar.CALENDAR c 
GROUP BY 1,2,3,4,5
)c
ON  c.month_of_calendar  BETWEEN   c.month_of_calendar - c.month_of_year +EXTRACT(MONTH FROM a.datum) AND  c.month_of_calendar - c.month_of_year +EXTRACT(MONTH FROM ADD_MONTHS(a.datum, +2))
AND  c.year_of_calendar BETWEEN   EXTRACT(YEAR FROM a.datum) AND EXTRACT(YEAR FROM ADD_MONTHS(a.datum, + 2))

WHERE UMSATZART = 'G'
AND betrag BETWEEN 300 AND 3000
AND textzeile_123 NOT LIKE '%gehalt%'
AND textzeile_123 NOT LIKE '%lohn%'
AND textzeile_123 NOT LIKE '%reisekostenabrechnung%'
AND 
			(
			textzeile_123 LIKE '%abrechnung%'
			 AND 
						 	(		textzeile_123 LIKE '%'||TRIM(year_of_calendar||month_2dig)||'%' /* jahrMonat*/
						 OR
						 		(textzeile_123 LIKE TRIM('%'||TRIM(year_of_calendar)||'%') AND textzeile_123 LIKE TRIM('%'||TRIM(month_2dig)||'%')) /*jahr, Monat*/
						 OR
						 		(textzeile_123 LIKE TRIM('%'||monat_text||'%')) /*monat text*/
						  OR
						 		(textzeile_123 LIKE TRIM('%'||SUBSTR(CAST(year_of_calendar AS CHAR(4)),3,2)||'%') AND textzeile_123 LIKE TRIM('%'||TRIM(month_2dig)||'%')) /*jahr 2stellig, monat 2 stellig*/
						 )
 OR
			(
			 textzeile_123 LIKE '%abrechnung%'
			 AND 
						 (		kundendaten_123 LIKE '%'||TRIM(year_of_calendar||month_2dig)||'%' /* jahrMonat*/
						 
						 OR
						 		(kundendaten_123 LIKE TRIM('%'||TRIM(year_of_calendar)||'%') AND kundendaten_123 LIKE TRIM('%'||TRIM(month_2dig)||'%')) /*jahr, Monat*/
						 OR
						 		(kundendaten_123 LIKE TRIM('%'||monat_text||'%')) /*monat text*/
						 OR
						 		(kundendaten_123 LIKE TRIM('%'||SUBSTR(CAST(year_of_calendar AS CHAR(4)),3,2)||'%') AND kundendaten_123 LIKE TRIM('%'||TRIM(month_2dig)||'%')) /*jahr 2stellig, monat 2 stellig*/
						 )
			 )
 )
 
QUALIFY anz_gs_name < 12
AND anz_ls_name > 10
)a GROUP BY 1,2,3,4,5,6

HAVING count_salary_6m >=1
)a QUALIFY ROW_NUMBER() OVER (PARTITION BY a.ende_beobachtung_datum
,a.kontonummer
,a.institutszuordnung
,a.kundennummer
,a.ls_kontonummer ORDER BY a.datum_letzte_alte_zahlung DESC) = 1
)a QUALIFY ROW_NUMBER() OVER (PARTITION BY a.ende_beobachtung_datum
,a.kontonummer
,a.institutszuordnung
,a.kundennummer
,a.ls_name ORDER BY a.datum_letzte_alte_zahlung DESC) = 1;

/*
############################################################################################
                               GET NEW employer 
############################################################################################
*/

/*
#####  stage TABLE TO GROUP ######
*/
DELETE
FROM da_twm_result_seg.lab_arbeitgeber_wechsel_basis T 
WHERE EXISTS (
    SEL * FROM da_twm_result_seg.lab_arbeitgeber_wechsel_basis neu
    WHERE neu.INSTITUTSZUORDNUNG = T.INSTITUTSZUORDNUNG
    AND neu.KUNDENNUMMER = T.KUNDENNUMMER
	AND T.ende_beobachtung_datum = CURRENT_DATE - EXTRACT(DAY FROM CURRENT_DATE)+1
    )
;



	INSERT INTO da_twm_result_seg.lab_arbeitgeber_wechsel_basis

	SEL
	a.ende_beobachtung_datum
	,a.kundennummer
	,a.institutszuordnung
	,MAX(a.ls_kontonummer) AS ls_kontonummer_aktuell
	,MAX(a.ls_name) AS ls_name_aktuell
	,MAX(a.datum_neue_zahlung) AS datum_neue_zahlung
	,SUM(betrag_1m_sum) AS betrag_1m_sum
	,a.ls_kontonummer_c
	,a.ls_name_c
	,a.datum_letzte_alte_zahlung_c
	,a.count_salary_6m_c
	,a.betrag_6m_ds_c
	,MAX(CASE WHEN a.kundennummer_b IS NULL THEN 1 ELSE 0 END ) AS neuer_arbeitgeber
	,MIN(CASE WHEN a.kundennummer_b IS NULL THEN 1 ELSE 0 END ) AS nur_neuer_arbeitgeber
	,MIN(CASE WHEN a.kundennummer_c IS NULL THEN 1 ELSE 0 END ) AS neuer_lohn


	FROM
	(
	SEL 
	a.*
	,ROW_NUMBER() OVER (PARTITION BY a.ende_beobachtung_datum, a.kundennummer,a.institutszuordnung ORDER BY Betrag_1m_sum DESC) AS nr
	,b.kundennummer AS kundennummer_b
	,c.kundennummer AS kundennummer_c
	,c.ls_kontonummer AS ls_kontonummer_c
	,c.ls_name AS ls_name_c
	,c.datum_letzte_alte_zahlung AS datum_letzte_alte_zahlung_c
	,c.count_salary_6m AS count_salary_6m_c
	,c.betrag_6m_ds AS betrag_6m_ds_C
	
	FROM

	da_twm_result_seg.lab_gehalt_1m a

	LEFT JOIN da_twm_result_seg.lab_gehalt_6m b
	ON a.ende_beobachtung_datum = b.ende_beobachtung_datum
	AND a.kundennummer = b.kundennummer
	AND a.institutszuordnung = b.institutszuordnung
	AND a.kontonummer = b.kontonummer
	AND (a.ls_kontonummer = b.ls_kontonummer
	OR  a.ls_name = b.ls_name)

	LEFT JOIN 
	(SEL a.ende_beobachtung_datum
	,a.kundennummer
	,a.institutszuordnung
	,MAX(a.ls_kontonummer) AS ls_kontonummer
	,MAX(a.ls_name) AS ls_name
	,MAX(a.datum_letzte_alte_zahlung) AS datum_letzte_alte_zahlung
	,MAX(a.count_salary_6m) AS count_salary_6m
	,MAX(a.betrag_6m_ds) AS betrag_6m_ds
	FROM
	da_twm_result_seg.lab_gehalt_6m a GROUP BY 1,2,3)c
	ON a.ende_beobachtung_datum = c.ende_beobachtung_datum
	AND a.kundennummer = c.kundennummer
	AND a.institutszuordnung = c.institutszuordnung
	CROSS JOIN (SEL MAX(ENDE_BEOBACHTUNG_DATUM) AS ende_beobachtung_datum FROM vm_acrm_reporting.DASHBOARD WHERE KUNDENBASIS = 5) p


	WHERE a.ende_beobachtung_datum = p.ende_beobachtung_datum
	
	)a GROUP BY 1,2,3,8,9,10,11,12
;
/*
	#######################################################################

Arbeitgeber wechsel aus kde_kde_relation

	#######################################################################
*/	

INSERT INTO da_twm_result_seg.lab_arbeitgeber_wechsel_basis


SEL a.*
FROM
(
SEL
a.datum_von - EXTRACT(DAY FROM a.datum_von) +1 AS ende_beobachtung_datum
,a.kundennummer
,a.institutszuordnung
,NULL AS ls_kontonummer_aktuell
,OREPLACE(arbeitgeber,'*','') AS ls_name_aktuell
,NULL AS datum_neue_zahlung
,NULL AS betrag_1m_sum
,NULL AS ls_kontonummer_c
,OREPLACE(MAX(arbeitgeber) OVER(PARTITION BY  a.kundennummer,a.institutszuordnung ORDER BY a.datum_von ASC ROWS BETWEEN 1 PRECEDING AND 1 PRECEDING),'*','') AS ls_name_c
,NULL AS  datum_letzte_alte_zahlung_c   
,NULL AS  count_salary_6m_c             
,NULL AS  betrag_6m_ds_C                
,1 AS  neuer_arbeitgeber             
,1 AS  nur_neuer_arbeitgeber         
,CASE WHEN ls_name_c IS NULL THEN 1 ELSE 0 END AS neuer_lohn                    
FROM
(
SEL a.*
,ROW_NUMBER() OVER (PARTITION BY a.kundennummer,a.institutszuordnung ORDER BY a.datum_von DESC) AS rf
,COUNT(*) OVER (PARTITION BY a.kundennummer,a.institutszuordnung ) AS anz_arbeitgeber
FROM
(
SEL 
a.*,b.KUNDENNAME AS arbeitgeber

,ROW_NUMBER() OVER (PARTITION BY a.datum_von - EXTRACT(DAY FROM a.datum_von) +1, a.kundennummer,a.institutszuordnung ORDER BY a.datum_von DESC ) AS rf_monat

FROM vb_data.LDR_KDE_KDE_REL a

LEFT JOIN vb_data.LDR_KDE_BASIS b
ON a.KUNDENNUMMER_AN = b.KUNDENNUMMER
AND a.INSTITUTSZUORDNUNG_AN = b.INSTITUTSZUORDNUNG


WHERE BEZIEHUNGSART = 41
AND b.DATUM_Bis = '3500-12-31'
/*AND a.kundennummer = 675070	
AND a.institutszuordnung = 0109*/

QUALIFY rf_monat = 1
)a QUALIFY anz_arbeitgeber >1

)a QUALIFY /*ende_beobachtung_datum = CURRENT_DATE - EXTRACT(DAY FROM CURRENT_DATE) +1  AND*/ neuer_lohn = 0
AND ls_name_aktuell <> ls_name_c
)a
LEFT JOIN  da_twm_result_seg.lab_arbeitgeber_wechsel_basis b
ON a.ende_beobachtung_datum = b.ENDE_BEOBACHTUNG_DATUM
AND a.kundennummer = b.KUNDENNUMMER
AND a.institutszuordnung = b.INSTITUTSZUORDNUNG

WHERE b.KUNDENNUMMER IS NULL
AND a.ende_beobachtung_datum = CURRENT_DATE - EXTRACT(DAY FROM CURRENT_DATE)+1
;




/*#####################         ausschluss von arbeitgeber wechsel wo nur name leicht abgewandelt oder neue ls_kontonummer       ####################################################*/
DELETE FROM
da_twm_result_seg.lab_arbeitgeber_wechsel_ber T 
WHERE EXISTS (
    SEL * FROM da_twm_result_seg.lab_arbeitgeber_wechsel_ber neu
    WHERE neu.INSTITUTSZUORDNUNG = T.INSTITUTSZUORDNUNG
    AND neu.KUNDENNUMMER = T.KUNDENNUMMER
	AND T.ende_beobachtung_datum = CURRENT_DATE - EXTRACT(DAY FROM CURRENT_DATE)+1
    )
;

INSERT INTO  da_twm_result_seg.lab_arbeitgeber_wechsel_ber
SEL a.*

,CAST(OREPLACE(OREPLACE(OREPLACE(OREPLACE(UPPER(STRTOK(OREPLACE(OREPLACE(ls_name_aktuell,',',' '),'.',' '),' ',1)),'GMBH','x'),'AUSTRIA','y'),'STADT','z'),'WIEN','W') AS VARCHAR(99)) AS ls_name_aktuell_1
,CAST(OREPLACE(OREPLACE(OREPLACE(OREPLACE(UPPER(STRTOK(OREPLACE(OREPLACE(ls_name_aktuell,',',' '),'.',' '),' ',2)),'GMBH','x'),'AUSTRIA','y'),'STADT','z'),'WIEN','W') AS VARCHAR(99)) AS ls_name_aktuell_2
,CAST(OREPLACE(OREPLACE(OREPLACE(OREPLACE(UPPER(STRTOK(OREPLACE(OREPLACE(ls_name_aktuell,',',' '),'.',' '),' ',3)),'GMBH','x'),'AUSTRIA','y'),'STADT','z'),'WIEN','W') AS VARCHAR(99)) AS ls_name_aktuell_3

,CAST(OREPLACE(OREPLACE(OREPLACE(OREPLACE(UPPER(STRTOK(OREPLACE(OREPLACE(ls_name_c,',',' '),'.',' '),' ',1)),'GMBH','x'),'AUSTRIA','y'),'STADT','z'),'WIEN','W') AS VARCHAR(99)) AS ls_name_c_1
,CAST(OREPLACE(OREPLACE(OREPLACE(OREPLACE(UPPER(STRTOK(OREPLACE(OREPLACE(ls_name_c,',',' '),'.',' '),' ',2)),'GMBH','x'),'AUSTRIA','y'),'STADT','z'),'WIEN','W') AS VARCHAR(99)) AS ls_name_c_2
,CAST(OREPLACE(OREPLACE(OREPLACE(OREPLACE(UPPER(STRTOK(OREPLACE(OREPLACE(ls_name_c,',',' '),'.',' '),' ',3)),'GMBH','x'),'AUSTRIA','y'),'STADT','z'),'WIEN','W') AS VARCHAR(99)) AS ls_name_c_3


,CASE WHEN
ls_name_aktuell_1 LIKE   '%'||ls_name_c_1||'%' AND LENGTH(ls_name_c_1)>2 
OR ls_name_aktuell_1 LIKE   '%'||ls_name_c_2||'%' AND LENGTH(ls_name_c_2)>2 
OR ls_name_aktuell_1 LIKE   '%'||ls_name_c_3||'%'AND LENGTH(ls_name_c_3)>2 

OR ls_name_aktuell_2 LIKE   '%'||ls_name_c_1||'%' AND LENGTH(ls_name_c_1)>2 
OR ls_name_aktuell_2 LIKE   '%'||ls_name_c_2||'%' AND LENGTH(ls_name_c_2)>2 
OR ls_name_aktuell_2 LIKE   '%'||ls_name_c_3||'%' AND LENGTH(ls_name_c_3)>2 

OR ls_name_aktuell_3 LIKE   '%'||ls_name_c_1||'%' AND LENGTH(ls_name_c_1)>2 
OR ls_name_aktuell_3 LIKE   '%'||ls_name_c_2||'%' AND LENGTH(ls_name_c_2)>2 
OR ls_name_aktuell_3 LIKE   '%'||ls_name_c_3||'%' AND LENGTH(ls_name_c_3)>2 

OR ls_name_c_1 LIKE   '%'||ls_name_aktuell_1||'%' AND LENGTH(ls_name_aktuell_1)>2 
OR ls_name_c_1 LIKE   '%'||ls_name_aktuell_2||'%' AND LENGTH(ls_name_aktuell_2)>2 
OR ls_name_c_1 LIKE   '%'||ls_name_aktuell_3||'%'AND LENGTH(ls_name_aktuell_3)>2 

OR ls_name_c_2 LIKE   '%'||ls_name_aktuell_1||'%' AND LENGTH(ls_name_aktuell_1)>2 
OR ls_name_c_2 LIKE   '%'||ls_name_aktuell_2||'%' AND LENGTH(ls_name_aktuell_2)>2 
OR ls_name_c_2 LIKE   '%'||ls_name_aktuell_3||'%' AND LENGTH(ls_name_aktuell_3)>2 

OR ls_name_c_3 LIKE   '%'||ls_name_aktuell_1||'%' AND LENGTH(ls_name_aktuell_1)>2 
OR ls_name_c_3 LIKE   '%'||ls_name_aktuell_2||'%' AND LENGTH(ls_name_aktuell_2)>2 
OR ls_name_c_3 LIKE   '%'||ls_name_aktuell_3||'%' AND LENGTH(ls_name_aktuell_3)>2 


OR ( SUBSTR(LS_KONTONUMMER_aktuell,1,8) = '00005090' AND SUBSTR(LS_KONTONUMMER_c,1,8) = '00005090')
THEN 1 ELSE 0 END AS arbeitgeber_token_ident

FROM  da_twm_result_seg.lab_arbeitgeber_wechsel_basis a

CROSS JOIN (SEL MAX(ENDE_BEOBACHTUNG_DATUM) AS ende_beobachtung_datum FROM vm_acrm_reporting.DASHBOARD WHERE KUNDENBASIS = 5) p


WHERE a.ende_beobachtung_datum = p.ende_beobachtung_datum
AND arbeitgeber_token_ident = 0
AND  nur_neuer_arbeitgeber = 1
AND neuer_lohn = 0/*  nur Kunden die schon im vormonat gehaltbezug identifiziert wurde*/

;




/*#################################################################################################################################*/





/*############################################################################################
                               get customers`company size category
############################################################################################
*/

/*REPLACE VIEW da_twm_result_SEG.lab_kde_arbeitgeber_anz_mitarbeiter
AS
(
SEL a.*,b.anz_kde_ls_name,b.grp_anz_ma FROM da_twm_result_seg.lab_gehalt_6m a
JOIN da_twm_result_seg.lab_lu_arbeitgeber_anz_mitarbeiter b
ON a.LS_NAME = b.ls_name
AND a.ende_beobachtung_datum = b.ende_beobachtung_datum

);*/


/*############################################################################################
                               get unique actual and previous customer salary payment 
############################################################################################
*/

DELETE
FROM da_twm_result_seg.lab_arbeitgeber_gehalt T 
WHERE  EXISTS (
    SEL * FROM da_twm_result_seg.lab_arbeitgeber_gehalt neu
    WHERE neu.INSTITUTSZUORDNUNG = T.INSTITUTSZUORDNUNG
    AND neu.KUNDENNUMMER = T.KUNDENNUMMER
	AND T.ende_beobachtung_datum = CURRENT_DATE - EXTRACT(DAY FROM CURRENT_DATE)+1
    )
;


INSERT INTO da_twm_result_seg.lab_arbeitgeber_gehalt

SEL 
a.ENDE_BEOBACHTUNG_DATUM
,a.kundennummer
,a.INSTITUTSZUORDNUNG
,a.arbeitgeber_akt_1
,a.gehalt_akt_1
,a.datum_neue_zahlung_akt_1
,a.arbeitgeber_akt_2
,a.gehalt_akt_2
,a.datum_neue_zahlung_akt_2
,a.gehalt_ttl_akt

,b.arbeitgeber_prev_1
,b.gehalt_prev_1
,b.datum_letzte_alte_zahlung_prev_1
,b.arbeitgeber_prev_2
,b.gehalt_prev_2
,b.datum_letzte_alte_zahlung_prev_2
,b.gehalt_ttl_prev
FROM
(
SEL
a.ENDE_BEOBACHTUNG_DATUM
,a.kundennummer
,a.INSTITUTSZUORDNUNG
,a.arbeitgeber_akt_1
,a.gehalt_akt_1
,a.datum_neue_zahlung_akt_1
,CASE WHEN EXTRACT(MONTH FROM a.datum_neue_zahlung_akt_2) = EXTRACT(MONTH FROM a.datum_neue_zahlung_akt_1) THEN a.arbeitgeber_akt_2 ELSE NULL END AS arbeitgeber_akt_2
,CASE WHEN EXTRACT(MONTH FROM a.datum_neue_zahlung_akt_2) = EXTRACT(MONTH FROM a.datum_neue_zahlung_akt_1) THEN a.gehalt_akt_2 ELSE NULL END AS gehalt_akt_2
,CASE WHEN EXTRACT(MONTH FROM a.datum_neue_zahlung_akt_2) = EXTRACT(MONTH FROM a.datum_neue_zahlung_akt_1) THEN a.datum_neue_zahlung_akt_2 ELSE NULL END AS datum_neue_zahlung_akt_2
,a.gehalt_akt_1+ZEROIFNULL(gehalt_akt_2) AS gehalt_ttl_akt
FROM
(
SEL 
a.ENDE_BEOBACHTUNG_DATUM
,a.kundennummer
,a.INSTITUTSZUORDNUNG
,MAX(CASE WHEN gehalt_nr = 1 THEN ls_name ELSE NULL end) AS arbeitgeber_akt_1
,MAX(CASE WHEN gehalt_nr = 1 THEN Betrag_1m_sum ELSE NULL end) AS gehalt_akt_1
,MAX(CASE WHEN gehalt_nr = 1 THEN datum_neue_zahlung ELSE NULL end) AS datum_neue_zahlung_akt_1
,MAX(CASE WHEN gehalt_nr = 2 THEN ls_name ELSE NULL end) AS arbeitgeber_akt_2
,MAX(CASE WHEN gehalt_nr = 2 THEN Betrag_1m_sum ELSE NULL end) AS gehalt_akt_2
,MAX(CASE WHEN gehalt_nr = 2 THEN datum_neue_zahlung ELSE NULL end) AS datum_neue_zahlung_akt_2
FROM
(
SEL a.*
,ROW_NUMBER() OVER(PARTITION BY a.ENDE_BEOBACHTUNG_DATUM,a.KUNDENNUMMER,a.INSTITUTSZUORDNUNG ORDER BY a.Betrag_1m_sum DESC) AS gehalt_nr
FROM da_twm_result_seg.lab_gehalt_1m a
)a GROUP BY 1,2,3
)a
)a
LEFT JOIN
(
SEL
a.ENDE_BEOBACHTUNG_DATUM
,a.kundennummer
,a.INSTITUTSZUORDNUNG
,a.arbeitgeber_prev_1
,a.gehalt_prev_1
,a.datum_letzte_alte_zahlung_prev_1
,CASE WHEN EXTRACT(MONTH FROM a.datum_letzte_alte_zahlung_prev_2) = EXTRACT(MONTH FROM a.datum_letzte_alte_zahlung_prev_1) THEN a.arbeitgeber_prev_2 ELSE NULL END AS arbeitgeber_prev_2
,CASE WHEN EXTRACT(MONTH FROM a.datum_letzte_alte_zahlung_prev_2) = EXTRACT(MONTH FROM a.datum_letzte_alte_zahlung_prev_1) THEN a.gehalt_prev_2 ELSE NULL END AS gehalt_prev_2
,CASE WHEN EXTRACT(MONTH FROM a.datum_letzte_alte_zahlung_prev_2) = EXTRACT(MONTH FROM a.datum_letzte_alte_zahlung_prev_1) THEN a.datum_letzte_alte_zahlung_prev_2 ELSE NULL END AS datum_letzte_alte_zahlung_prev_2
,a.gehalt_prev_1+ZEROIFNULL(gehalt_prev_2) AS gehalt_ttl_prev
FROM
(
SEL 
a.ENDE_BEOBACHTUNG_DATUM
,a.kundennummer
,a.INSTITUTSZUORDNUNG
,MAX(CASE WHEN gehalt_nr = 1 THEN ls_name ELSE NULL end) AS arbeitgeber_prev_1
,MAX(CASE WHEN gehalt_nr = 1 THEN Betrag_6m_ds ELSE NULL end) AS gehalt_prev_1
,MAX(CASE WHEN gehalt_nr = 1 THEN datum_letzte_alte_zahlung ELSE NULL end) AS datum_letzte_alte_zahlung_prev_1
,MAX(CASE WHEN gehalt_nr = 2 THEN ls_name ELSE NULL end) AS arbeitgeber_prev_2
,MAX(CASE WHEN gehalt_nr = 2 THEN Betrag_6m_ds ELSE NULL end) AS gehalt_prev_2
,MAX(CASE WHEN gehalt_nr = 2 THEN datum_letzte_alte_zahlung ELSE NULL end) AS datum_letzte_alte_zahlung_prev_2
FROM
(
SEL a.*
,ROW_NUMBER() OVER(PARTITION BY a.ENDE_BEOBACHTUNG_DATUM,a.KUNDENNUMMER,a.INSTITUTSZUORDNUNG ORDER BY a.Betrag_6m_ds DESC) AS gehalt_nr
FROM da_twm_result_seg.lab_gehalt_6m a
)a GROUP BY 1,2,3
)a
)b ON a.KUNDENNUMMER = b.kundennummer
AND a.INSTITUTSZUORDNUNG = b.INSTITUTSZUORDNUNG
AND a.ENDE_BEOBACHTUNG_DATUM = b.ende_beobachtung_datum
;
/*####################################################################################

  zusammenführen Arbeitgeber aus Umsatz und Arbeitgeber aus Kde_kde_Rel 

####################################################################################*/

DELETE
FROM da_twm_result_seg.lab_arbeitgeber_gehalt_zus T 
WHERE  EXISTS (
    SEL * FROM da_twm_result_seg.lab_arbeitgeber_gehalt_zus neu
    WHERE neu.INSTITUTSZUORDNUNG = T.INSTITUTSZUORDNUNG
    AND neu.KUNDENNUMMER = T.KUNDENNUMMER
	AND T.ende_beobachtung_datum = CURRENT_DATE - EXTRACT(DAY FROM CURRENT_DATE)+1
    )
;

INSERT INTO  da_twm_result_seg.lab_arbeitgeber_gehalt_zus

SEL 
a.ende_beobachtung_datum
,a.kundennummer
,a.institutszuordnung
,CASE WHEN gehalt_1_coalesce = 0 OR  gehalt_1_coalesce IS NULL THEN gehalt_1_coalesce_partition ELSE gehalt_1_coalesce end AS gehalt
,gehalt_1_coalesce AS gehalt_orig
,arbeitgeber_coalesce_2 AS arbeitgeber
,trans_haben_index
,kde_rel AS kde_kde_rel_index
,CASE WHEN gehalt_1_coalesce = 0 OR  gehalt_1_coalesce IS NULL AND GEHALt IS NOT NULL THEN 1 ELSE 0 end AS gehalt_ersatzwert_index
FROM
(
SEL a.*
,CASE WHEN getAge(a.GEBURTSDATUM,CURRENT_DATE) <20 THEN 19
WHEN getAge(a.GEBURTSDATUM,CURRENT_DATE) >80 THEN 85
ELSE TRUNC(getAge(a.GEBURTSDATUM,CURRENT_DATE)/5)*5 end AS altersklasse


,AVG(
CASE 
WHEN gehalt_1_coalesce < 300 THEN 300 
WHEN gehalt_1_coalesce > 7500 THEN 7500
ELSE gehalt_1_coalesce 
end
) OVER (
PARTITION BY arbeitgeber_coalesce_2,
CASE WHEN getAge(a.GEBURTSDATUM,CURRENT_DATE) <20 THEN 19
WHEN getAge(a.GEBURTSDATUM,CURRENT_DATE) >70 THEN 75
ELSE TRUNC(getAge(a.GEBURTSDATUM,CURRENT_DATE)/10)*10 end
													)AS gehalt_1_coalesce_partition


FROM
(
SEL a.*
,OREPLACE(arbeitgeber_coalesce,'*','') AS arbeitgeber_coalesce_2
,b.GEBURTSDATUM

FROM
(
SEL 
COALESCE(a.ende_beobachtung_datum,CURRENT_DATE - EXTRACT(DAY FROM CURRENT_DATE)+1) AS ende_beobachtung_datum
,COALESCE(a.institutszuordnung,b.institutszuordnung) AS institutszuordnung
,COALESCE(a.kundennummer,b.kundennummer) AS kundennummer
,COALESCE(a.arbeitgeber_prev_1,b.arbeitgeber) AS arbeitgeber_coalesce
,COALESCE(a.gehalt_prev_1,b.gehalt) AS gehalt_1_coalesce

,COALESCE(a.gehalt_ttl_akt,b.gehalt) AS gehalt_ttl_coalesce

,CASE WHEN a.gehalt_akt_1 IS NULL AND b.NETTOEINKOMMEN1 IS NULL
AND b.gehalt IS NOT NULL 
THEN 1 ELSE 0 END AS trans_haben_index
,CASE WHEN a.gehalt_akt_1 IS NULL THEN 1 ELSE 0 END AS kde_rel

FROM
(
SEL * FROM da_twm_result_seg.lab_arbeitgeber_gehalt a
WHERE a.ENDE_BEOBACHTUNG_DATUM =CURRENT_DATE - EXTRACT(DAY FROM CURRENT_DATE)+1 
)a
FULL OUTER JOIN
(
SEL a.*,b.KUNDENNAME AS arbeitgeber, s.nettoeinkommen1,h.TRAN_GIRO_BER_GEF_MON_EUR, COALESCE(s.nettoeinkommen1,h.TRAN_GIRO_BER_GEF_MON_EUR/14*12) AS gehalt

FROM vb_data.LDR_KDE_KDE_REL a

LEFT JOIN vb_data.LDR_KDE_BASIS b
ON a.KUNDENNUMMER_AN = b.KUNDENNUMMER
AND a.INSTITUTSZUORDNUNG_AN = b.INSTITUTSZUORDNUNG


LEFT JOIN 
(
SEL b.* FROM
vb_data.LDR_SCO_ANTR b
QUALIFY ROW_NUMBER() OVER(PARTITION BY b.KUNDENNUMMER,b.INSTITUTSZUORDNUNG ORDER BY b.datum DESC) = 1
)s
ON a.kundennummer = s.KUNDENNUMMER
AND a.institutszuordnung = s.INSTITUTSZUORDNUNG
AND b.KUNDENNAME = s.NAME_ARBEITGEB_KUNDE1

LEFT JOIN vm_ads.EADS_BEOBACHTUNG_HIST h
ON a.kundennummer = h.KUNDENNUMMER
AND a.institutszuordnung = h.INSTITUTSZUORDNUNG
AND h.ENDE_BEOBACHTUNG_DATUM = CURRENT_DATE - EXTRACT(DAY FROM CURRENT_DATE)+1 

LEFT JOIN vm_acrm_reporting.DASHBOARD d
ON a.KUNDENNUMMER = d.KUNDENNUMMER
AND a.INSTITUTSZUORDNUNG = d.INSTITUTSZUORDNUNG
AND d.ENDE_BEOBACHTUNG_DATUM = CURRENT_DATE - EXTRACT(DAY FROM CURRENT_DATE)+1 

WHERE BEZIEHUNGSART = 41
AND b.DATUM_Bis = '3500-12-31'
AND a.DATUM_Bis = '3500-12-31'
)b
ON a.kundennummer = b.KUNDENNUMMER
AND a.institutszuordnung = b.INSTITUTSZUORDNUNG
AND a.ende_beobachtung_datum BETWEEN b.datum_von AND b.datum_bis
)a
LEFT JOIN vb_data.LDR_KDE_BASIS b
ON a.kundennummer = b.KUNDENNUMMER
AND a.institutszuordnung = b.INSTITUTSZUORDNUNG
AND b.DATUM_Bis = '3500-12-31'
QUALIFY 1 = ROW_NUMBER() OVER(PARTITION BY a.kundennummer,a.institutszuordnung,a.ende_beobachtung_datum ORDER BY gehalt_1_coalesce DESC)
)a 
)a
;
/*####################################################################################

  arbeitgeber event 

####################################################################################*/

DELETE
FROM da_twm_result_seg.lab_arbeitgeber_event T 
WHERE  EXISTS (
    SEL * FROM da_twm_result_seg.lab_arbeitgeber_event neu
    WHERE neu.INSTITUTSZUORDNUNG = T.INSTITUTSZUORDNUNG
    AND neu.KUNDENNUMMER = T.KUNDENNUMMER
	AND T.ende_beobachtung_datum = CURRENT_DATE - EXTRACT(DAY FROM CURRENT_DATE)+1
    )
;


INSERT INTO da_twm_result_seg.lab_arbeitgeber_event
SEL 

a.ende_beobachtung_datum 
,a.kundennummer
,a.institutszuordnung
,MAX(CASE WHEN b.KUNDENNUMMER IS NOT NULL AND p.ls_name IS NULL THEN 1 ELSE 0 END ) AS arbeitgeberwechsel_1M
,MAX(CASE WHEN c.KUNDENNUMMER IS NOT NULL AND p.ls_name IS NULL THEN 1 ELSE 0 END ) AS arbeitgeberwechsel_6M
,MAX(CASE WHEN d.KUNDENNUMMER IS NOT NULL AND p.ls_name IS NULL THEN 1 ELSE 0 END ) AS arbeitgeberwechsel_12M

,MAX(CASE WHEN bb.KUNDENNUMMER IS NOT NULL THEN 1 ELSE 0 END ) AS neuer_LohnGehalt_1M
,MAX(CASE WHEN cc.KUNDENNUMMER IS NOT NULL THEN 1 ELSE 0 END ) AS neuer_LohnGehalt_6M
,MAX(CASE WHEN dd.KUNDENNUMMER IS NOT NULL THEN 1 ELSE 0 END ) AS neuer_LohnGehalt_12M

,MAX(CASE WHEN b.KUNDENNUMMER IS NOT NULL AND p.ls_name IS NOT NULL THEN 1 ELSE 0 END ) AS neu_pension_1M
,MAX(CASE WHEN c.KUNDENNUMMER IS NOT NULL AND p.ls_name IS NOT NULL THEN 1 ELSE 0 END ) AS neu_pension_6M
,MAX(CASE WHEN d.KUNDENNUMMER IS NOT NULL AND p.ls_name IS NOT NULL THEN 1 ELSE 0 END ) AS neu_pension_12M


FROM da_twm_result_seg.lab_arbeitgeber_gehalt_zus a
LEFT JOIN da_twm_result_seg.lab_arbeitgeber_wechsel_ber b
ON a.kundennummer = b.KUNDENNUMMER
AND a.institutszuordnung = b.INSTITUTSZUORDNUNG
AND a.ende_beobachtung_datum = b.ENDE_BEOBACHTUNG_DATUM

LEFT JOIN da_twm_result_seg.lab_arbeitgeber_wechsel_ber c
ON a.kundennummer = c.KUNDENNUMMER
AND a.institutszuordnung = c.INSTITUTSZUORDNUNG
AND c.ENDE_BEOBACHTUNG_DATUM >= ADD_MONTHS(a.ende_beobachtung_datum,-6)

LEFT JOIN da_twm_result_seg.lab_arbeitgeber_wechsel_ber d
ON a.kundennummer = d.KUNDENNUMMER
AND a.institutszuordnung = d.INSTITUTSZUORDNUNG
AND d.ENDE_BEOBACHTUNG_DATUM >= ADD_MONTHS(a.ende_beobachtung_datum,-12)

LEFT JOIN 
(SEL a.*
FROM
(
SEL b.ende_beobachtung_datum,b.KUNDENNUMMER,b.INSTITUTSZUORDNUNG,neuer_lohn,MIN(b.ende_beobachtung_datum)OVER (PARTITION BY b.KUNDENNUMMER,b.INSTITUTSZUORDNUNG) AS erstes FROM
da_twm_result_seg.lab_arbeitgeber_wechsel_basis b
QUALIFY erstes <  b.ende_beobachtung_datum
)a WHERE neuer_lohn = 1
)bb
ON a.kundennummer = bb.KUNDENNUMMER
AND a.institutszuordnung = bb.INSTITUTSZUORDNUNG
AND a.ende_beobachtung_datum = bb.ENDE_BEOBACHTUNG_DATUM

LEFT JOIN 
(
SEL a.*
FROM
(
SEL b.ende_beobachtung_datum,b.KUNDENNUMMER,b.INSTITUTSZUORDNUNG,neuer_lohn,MIN(b.ende_beobachtung_datum)OVER (PARTITION BY b.KUNDENNUMMER,b.INSTITUTSZUORDNUNG) AS erstes FROM
da_twm_result_seg.lab_arbeitgeber_wechsel_basis b
QUALIFY erstes <  b.ende_beobachtung_datum
)a WHERE neuer_lohn = 1
)cc
ON a.kundennummer = cc.KUNDENNUMMER
AND a.institutszuordnung = cc.INSTITUTSZUORDNUNG
AND cc.ENDE_BEOBACHTUNG_DATUM >= ADD_MONTHS(a.ende_beobachtung_datum,-6)

LEFT JOIN 
(SEL a.*
FROM
(
SEL b.ende_beobachtung_datum,b.KUNDENNUMMER,b.INSTITUTSZUORDNUNG,neuer_lohn,MIN(b.ende_beobachtung_datum)OVER (PARTITION BY b.KUNDENNUMMER,b.INSTITUTSZUORDNUNG) AS erstes FROM
da_twm_result_seg.lab_arbeitgeber_wechsel_basis b
QUALIFY erstes <  b.ende_beobachtung_datum
)a WHERE neuer_lohn = 1
)dd
ON a.kundennummer = dd.KUNDENNUMMER
AND a.institutszuordnung = dd.INSTITUTSZUORDNUNG
AND dd.ENDE_BEOBACHTUNG_DATUM >= ADD_MONTHS(a.ende_beobachtung_datum,-12)

LEFT JOIN da_twm_result_seg.lab_lu_pensionskassen p
ON a.arbeitgeber = p.ls_name

WHERE a.ende_beobachtung_datum = CURRENT_DATE - EXTRACT(DAY FROM CURRENT_DATE)+1

GROUP BY 1,2,3
;



/*############################################################################################
                               get ttl number of employees for each company
############################################################################################
*/

DELETE
FROM da_twm_result_seg.lab_lu_arbeitgeber_anz_mitarbeiter T 
WHERE  EXISTS (
    SEL * FROM da_twm_result_seg.lab_lu_arbeitgeber_anz_mitarbeiter neu
    WHERE neu.ls_name = T.ls_name
    	AND T.ende_beobachtung_datum = CURRENT_DATE - EXTRACT(DAY FROM CURRENT_DATE)+1
    )
;

INSERT INTO da_twm_result_seg.lab_lu_arbeitgeber_anz_mitarbeiter

SEL
a.ende_beobachtung_datum
,CASE WHEN a.anz_kde_ls_name < 20 THEN 'grp_1' ELSE a.arbeitgeber END AS ls_name
,SUM(a.anz_kde_ls_name) AS anz_mitarbeiter_cap
FROM
(
SEL 
a.ende_beobachtung_datum
,TRIM(a.arbeitgeber) AS arbeitgeber
,COUNT(DISTINCT a.kundennummer||a.institutszuordnung) AS anz_kde_ls_name
FROM da_twm_result_seg.lab_arbeitgeber_gehalt_zus a 
WHERE 
a.ende_beobachtung_datum = CURRENT_DATE - EXTRACT(DAY FROM CURRENT_DATE) +1
GROUP BY 1,2
)a GROUP BY 1,2

;


/*############################################################################################
                               get customers` product saturation per company
############################################################################################
*/
/*
#######################################################################################################################
Stageing Table produkte je Kunde je Ende Beobachtung Datum
#######################################################################################################################
*/

CREATE  TABLE da_twm_result_seg.stage_kde_produkt
AS
(
SEL *
FROM
(
SEL a.KUNDENNUMMER
,a.INSTITUTSZUORDNUNG
, b.PK_Gruppe_Text
,CASE WHEN MIN(a.datum_von) < CURRENT_DATE - EXTRACT(DAY FROM CURRENT_DATE) +1   THEN CURRENT_DATE - EXTRACT(DAY FROM CURRENT_DATE) +1  
ELSE MIN(a.datum_von)  - EXTRACT(DAY FROM  MIN(a.datum_von)) +1 END AS ende_beobachtung_datum
FROM Vb_data.EXT_KTO_BASIS a
JOIN vb_lookup.PROD_BED_HIER b
ON a.PROD_BED_DETAIL = b.PROD_BED_DETAIL
GROUP BY 1,2,3/*,4,5*/
)a WHERE a.ende_beobachtung_datum = CURRENT_DATE - EXTRACT(DAY FROM CURRENT_DATE) +1  
)WITH DATA PRIMARY INDEX (ende_beobachtung_datum,KUNDENNUMMER,INSTITUTSZUORDNUNG,PK_Gruppe_Text) ;

/*SEL * FROM da_twm_result_seg.stage_kde_produkt*/

/*
#######################################################################################################################
Stageing Table produkte je Kunde je Arbeitgeber je Ende Beobachtung Datum
#######################################################################################################################
*/
/*DROP TABLE da_twm_result_seg.stage_kde_arbeitgeber_produkt;*/
CREATE TABLE da_twm_result_seg.stage_kde_arbeitgeber_produkt
AS
(
SEL a.*
, b.PK_Gruppe_Text
FROM da_twm_result_seg.lab_arbeitgeber_gehalt_zus a
JOIN da_twm_result_seg.stage_kde_produkt  b
ON a.KUNDENNUMMER = b.kundennummer
AND a.INSTITUTSZUORDNUNG = b.institutszuordnung
/*AND x.PK_Gruppe_Text = b.PK_Gruppe_Text*/
AND a.ende_beobachtung_datum = b.ende_beobachtung_datum 
)WITH DATA PRIMARY INDEX (ende_beobachtung_datum,KUNDENNUMMER,INSTITUTSZUORDNUNG,PK_Gruppe_Text,arbeitgeber) ;

/*SEL * FROM da_twm_result_seg.stage_kde_arbeitgeber_produkt*/

/*
#######################################################################################################################
Stageing Table Anzahl Kunde je produkte je Arbeitgeber je Ende Beobachtung Datum
#######################################################################################################################
*/
/*DROP TABLE da_twm_result_seg.stage_arbeitgeber_produkt_anzKde;*/
CREATE TABLE da_twm_result_seg.stage_arbeitgeber_produkt_anzKde
AS
(
SEL 
 a.ende_beobachtung_datum
 ,a.arbeitgeber
 ,a.PK_Gruppe_Text
 ,COUNT( a.kundennummer||a.institutszuordnung) AS anz_kde_produkt
FROM da_twm_result_seg.stage_kde_arbeitgeber_produkt a
GROUP BY 1,2,3
)WITH DATA PRIMARY INDEX (ende_beobachtung_datum,PK_Gruppe_Text,arbeitgeber);
/*sel * from da_twm_result_seg.stage_arbeitgeber_produkt_anzKde*/
/*
#######################################################################################################################
Stageing Table anteil je produkte je Arbeitgeber je Ende Beobachtung Datum
#######################################################################################################################
*/
/*DROP TABLE da_twm_result_seg.stage_anteil_arbeitgeber_prod;*/
CREATE TABLE da_twm_result_seg.stage_anteil_arbeitgeber_prod
AS
(
SEL
a.ende_beobachtung_datum
,a.ls_name_lu AS arbeitgeber
,a.PK_Gruppe_Text
,SUM(a.anz_kde_produkt) AS anz_kde_produkt_AG
,MAX(anz_mitarbeiter_cap) AS anz_mitarbeiter_cap_all
,CAST(anz_kde_produkt_AG AS FLOAT)/CAST(anz_mitarbeiter_cap_all AS FLOAT) AS anteil_AG_prod
FROM
(
SEL 
a.*
,b.ls_name AS ls_name_lu
,COALESCE(b.anz_mitarbeiter_cap,x.anz_mitarbeiter_cap) AS anz_mitarbeiter_cap
FROM da_twm_result_seg.stage_arbeitgeber_produkt_anzKde a
LEFT JOIN da_twm_result_seg.lab_lu_arbeitgeber_anz_mitarbeiter b
ON a.arbeitgeber = b.ls_name
AND a.ende_beobachtung_datum = b.ende_beobachtung_datum
LEFT JOIN da_twm_result_seg.lab_lu_arbeitgeber_anz_mitarbeiter x
ON 'grp_1' = x.ls_name
AND a.ende_beobachtung_datum = x.ende_beobachtung_datum
)a GROUP BY 1,2,3
)WITH DATA PRIMARY INDEX (ende_beobachtung_datum,PK_Gruppe_Text,arbeitgeber);
/*sel * from  da_twm_result_seg.stage_anteil_arbeitgeber_prod*/
/*
#######################################################################################################################
Final LookupTable Produktanteil je Arbeitgeber je Ende Beobachtung Datum
#######################################################################################################################
*/

DELETE
FROM da_twm_result_seg.lab_lu_arbeitgeber_prd_anteil T 
WHERE  EXISTS (
    SEL * FROM da_twm_result_seg.lab_lu_arbeitgeber_prd_anteil neu
    WHERE  T.ende_beobachtung_datum = CURRENT_DATE - EXTRACT(DAY FROM CURRENT_DATE)+1
    )
;
INSERT INTO da_twm_result_seg.lab_lu_arbeitgeber_prd_anteil

SEL
a.ende_beobachtung_datum
,a.arbeitgeber
,MAX(CASE WHEN a.pk_gruppe_text = 'Investment' THEN anteil_AG_prod ELSE 0 END) AS anteil_arbeitgeber_Investment
,MAX(CASE WHEN a.pk_gruppe_text = 'Giro' THEN anteil_AG_prod ELSE 0 END) AS anteil_arbeitgeber_Giro
,MAX(CASE WHEN a.pk_gruppe_text = 'Kreditkarte' THEN anteil_AG_prod ELSE 0 END) AS anteil_arbeitgeber_Kreditkarte
,MAX(CASE WHEN a.pk_gruppe_text = 'Versicherung' THEN anteil_AG_prod ELSE 0 END) AS anteil_arbeitgeber_Versicherung
,MAX(CASE WHEN a.pk_gruppe_text = 'Longterm Spar' THEN anteil_AG_prod ELSE 0 END) AS anteil_arbeitgeber_LongtermSpar
,MAX(CASE WHEN a.pk_gruppe_text = 'Bauspar' THEN anteil_AG_prod ELSE 0 END) AS anteil_arbeitgeber_Bauspar
,MAX(CASE WHEN a.pk_gruppe_text = 'Konsumkredit' THEN anteil_AG_prod ELSE 0 END) AS anteil_arbeitgeber_Konsumkredit
,MAX(CASE WHEN a.pk_gruppe_text = 'Shortterm Spar' THEN anteil_AG_prod ELSE 0 END) AS anteil_arbeitgeber_ShorttermSpar
,MAX(CASE WHEN a.pk_gruppe_text = 'Wohnbaukredit' THEN anteil_AG_prod ELSE 0 END) AS anteil_arbeitgeber_Wohnbaukredit
FROM
da_twm_result_seg.stage_anteil_arbeitgeber_prod a
GROUP BY 1,2
;
/*
#######################################################################################################################
Final Table Produktanteil je Kunde je Arbeitgeber je Ende Beobachtung Datum
#######################################################################################################################
*/

DELETE
FROM da_twm_result_seg.lab_arbeitgeber_prd_anteil_kde T 
WHERE  EXISTS (
    SEL * FROM da_twm_result_seg.lab_arbeitgeber_prd_anteil_kde neu
    WHERE T.ende_beobachtung_datum = CURRENT_DATE - EXTRACT(DAY FROM CURRENT_DATE)+1
    )
;

INSERT INTO da_twm_result_seg.lab_arbeitgeber_prd_anteil_kde

SEL 
a.ende_beobachtung_datum
,a.kundennummer
,a.institutszuordnung
,a.arbeitgeber

,CASE WHEN b.arbeitgeber IS NULL THEN b1.anteil_arbeitgeber_Investment ELSE b.anteil_arbeitgeber_Investment END AS anteil_arbeitgeber_Investment
,CASE WHEN b.arbeitgeber IS NULL THEN b1.anteil_arbeitgeber_Giro ELSE b.anteil_arbeitgeber_Giro END AS anteil_arbeitgeber_Giro
,CASE WHEN b.arbeitgeber IS NULL THEN b1.anteil_arbeitgeber_Kreditkarte ELSE b.anteil_arbeitgeber_Kreditkarte END AS anteil_arbeitgeber_Kreditkarte
,CASE WHEN b.arbeitgeber IS NULL THEN b1.anteil_arbeitgeber_Versicherung ELSE b.anteil_arbeitgeber_Versicherung END AS anteil_arbeitgeber_Versicherung
,CASE WHEN b.arbeitgeber IS NULL THEN b1.anteil_arbeitgeber_LongtermSpar ELSE b.anteil_arbeitgeber_LongtermSpar END AS anteil_arbeitgeber_LongtermSpar
,CASE WHEN b.arbeitgeber IS NULL THEN b1.anteil_arbeitgeber_Bauspar ELSE b.anteil_arbeitgeber_Bauspar END AS anteil_arbeitgeber_Bauspar
,CASE WHEN b.arbeitgeber IS NULL THEN b1.anteil_arbeitgeber_Konsumkredit ELSE b.anteil_arbeitgeber_Konsumkredit END AS anteil_arbeitgeber_Konsumkredit
,CASE WHEN b.arbeitgeber IS NULL THEN b1.anteil_arbeitgeber_ShorttermSpar ELSE b.anteil_arbeitgeber_ShorttermSpar END AS anteil_arbeitgeber_ShorttermSpar
,CASE WHEN b.arbeitgeber IS NULL THEN b1.anteil_arbeitgeber_Wohnbaukredit ELSE b.anteil_arbeitgeber_Wohnbaukredit END AS anteil_arbeitgeber_Wohnbaukredit
,CASE WHEN b.arbeitgeber IS NULL THEN 1 ELSE 0 END AS Arbeitgeber_Grouped_index

FROM da_twm_result_seg.lab_arbeitgeber_gehalt_zus a
LEFT JOIN da_twm_result_seg.lab_lu_arbeitgeber_prd_anteil b
ON a.arbeitgeber = b.arbeitgeber
AND a.ende_beobachtung_datum = b.ende_beobachtung_datum

LEFT JOIN 
(SEL a.* FROM da_twm_result_seg.lab_lu_arbeitgeber_prd_anteil a
WHERE a.arbeitgeber IS NULL )b1 /*  Anteil für Arbeitgeber mit Mitarbeiteranzahl < 20 zusammengefasst zu einer gruppe */
ON a.ende_beobachtung_datum = b1.ende_beobachtung_datum

WHERE a.ende_beobachtung_datum = CURRENT_DATE - EXTRACT(DAY FROM CURRENT_DATE)+1

;




/*
#######################################################################################################################
drop staging tables
#######################################################################################################################
*/
DROP TABLE da_twm_result_seg.stage_kde_produkt;
DROP TABLE da_twm_result_seg.stage_kde_arbeitgeber_produkt;
DROP TABLE da_twm_result_seg.stage_arbeitgeber_produkt_anzKde;
DROP TABLE da_twm_result_seg.stage_anteil_arbeitgeber_prod;



REPLACE VIEW da_twm_result_seg.lab_arbeitgeber_prd_anteil_kpi
AS
(
SEL DISTINCT
ende_beobachtung_datum
,arbeitgeber

,AVG(a.anteil_arbeitgeber_Giro                   )    OVER(PARTITION  BY a.ende_beobaCHTUNG_datum) AS anteil_all_giro
,AVG(a.anteil_arbeitgeber_Kreditkarte		 ) 	  OVER(PARTITION  BY a.ende_beobaCHTUNG_datum) AS anteil_all_Kreditkarte
,AVG(a.anteil_arbeitgeber_ShorttermSpar	 ) 	   OVER(PARTITION  BY a.ende_beobaCHTUNG_datum) AS anteil_all_ShorttermSpar
,AVG(a.anteil_arbeitgeber_LongtermSpar	 ) 	  OVER(PARTITION  BY a.ende_beobaCHTUNG_datum) AS anteil_all_LongtermSpar
,AVG(a.anteil_arbeitgeber_Bauspar			 ) 	  OVER(PARTITION  BY a.ende_beobaCHTUNG_datum) AS anteil_all_Bauspar
,AVG(a.anteil_arbeitgeber_Versicherung	  )    OVER(PARTITION  BY a.ende_beobaCHTUNG_datum) AS anteil_all_Versicherung
,AVG(a.anteil_arbeitgeber_Investment	   ) 	 OVER(PARTITION  BY a.ende_beobaCHTUNG_datum) AS anteil_all_Investment
,AVG(a.anteil_arbeitgeber_Konsumkredit	 ) 	   OVER(PARTITION  BY a.ende_beobaCHTUNG_datum) AS anteil_all_Konsumkredit
,AVG(a.anteil_arbeitgeber_Wohnbaukredit	 ) 	 OVER(PARTITION  BY a.ende_beobaCHTUNG_datum) AS anteil_all_Wohnbaukredit

,a.anteil_arbeitgeber_Giro                    /NULLIFZERO(anteil_all_giro						) AS idx_giro	
,a.anteil_arbeitgeber_Kreditkarte		  /NULLIFZERO(anteil_all_Kreditkarte			) AS idx_kreditkarte
,a.anteil_arbeitgeber_ShorttermSpar	   /NULLIFZERO(anteil_all_ShorttermSpar		 ) AS idx_ShorttermSpar
,a.anteil_arbeitgeber_LongtermSpar	  /NULLIFZERO(anteil_all_LongtermSpar		) AS idx_LongtermSpar
,a.anteil_arbeitgeber_Bauspar			  /NULLIFZERO(anteil_all_Bauspar				) AS idx_Bauspar
,a.anteil_arbeitgeber_Versicherung	   /NULLIFZERO(anteil_all_Versicherung		  ) AS idx_Versicherung
,a.anteil_arbeitgeber_Investment	   	 /NULLIFZERO(anteil_all_Investment			 ) AS idx_Investment
,a.anteil_arbeitgeber_Konsumkredit	   /NULLIFZERO(anteil_all_Konsumkredit		 ) AS idx_Konsumkredit
,a.anteil_arbeitgeber_Wohnbaukredit	 /NULLIFZERO(anteil_all_Wohnbaukredit	 ) AS idx_Wohnbaukredit

,idx_giro/(NULLIFZERO(idx_giro)+NULLIFZERO(idx_kreditkarte)+NULLIFZERO(idx_ShorttermSpar)+NULLIFZERO(idx_LongtermSpar)+NULLIFZERO(idx_Bauspar)+NULLIFZERO(idx_Versicherung)+NULLIFZERO(idx_Investment)+NULLIFZERO(idx_Konsumkredit)+NULLIFZERO(idx_Wohnbaukredit)) AS prd_anteil_arbeitgeber_giro                    
,idx_kreditkarte/(NULLIFZERO(idx_giro)+NULLIFZERO(idx_kreditkarte)+NULLIFZERO(idx_ShorttermSpar)+NULLIFZERO(idx_LongtermSpar)+NULLIFZERO(idx_Bauspar)+NULLIFZERO(idx_Versicherung)+NULLIFZERO(idx_Investment)+NULLIFZERO(idx_Konsumkredit)+NULLIFZERO(idx_Wohnbaukredit)) AS prd_anteil_arbeitgeber_kreditkarte
,idx_ShorttermSpar/(NULLIFZERO(idx_giro)+NULLIFZERO(idx_kreditkarte)+NULLIFZERO(idx_ShorttermSpar)+NULLIFZERO(idx_LongtermSpar)+NULLIFZERO(idx_Bauspar)+NULLIFZERO(idx_Versicherung)+NULLIFZERO(idx_Investment)+NULLIFZERO(idx_Konsumkredit)+NULLIFZERO(idx_Wohnbaukredit)) AS prd_anteil_arbeitgeber_ShorttermSpar
,idx_LongtermSpar/(NULLIFZERO(idx_giro)+NULLIFZERO(idx_kreditkarte)+NULLIFZERO(idx_ShorttermSpar)+NULLIFZERO(idx_LongtermSpar)+NULLIFZERO(idx_Bauspar)+NULLIFZERO(idx_Versicherung)+NULLIFZERO(idx_Investment)+NULLIFZERO(idx_Konsumkredit)+NULLIFZERO(idx_Wohnbaukredit)) AS prd_anteil_arbeitgeber_LongtermSpar
,idx_Bauspar/(NULLIFZERO(idx_giro)+NULLIFZERO(idx_kreditkarte)+NULLIFZERO(idx_ShorttermSpar)+NULLIFZERO(idx_LongtermSpar)+NULLIFZERO(idx_Bauspar)+NULLIFZERO(idx_Versicherung)+NULLIFZERO(idx_Investment)+NULLIFZERO(idx_Konsumkredit)+NULLIFZERO(idx_Wohnbaukredit)) AS prd_anteil_arbeitgeber_Bauspar
,idx_Versicherung/(NULLIFZERO(idx_giro)+NULLIFZERO(idx_kreditkarte)+NULLIFZERO(idx_ShorttermSpar)+NULLIFZERO(idx_LongtermSpar)+NULLIFZERO(idx_Bauspar)+NULLIFZERO(idx_Versicherung)+NULLIFZERO(idx_Investment)+NULLIFZERO(idx_Konsumkredit)+NULLIFZERO(idx_Wohnbaukredit)) AS prd_anteil_arbeitgeber_Versicherung
,idx_Investment/(NULLIFZERO(idx_giro)+NULLIFZERO(idx_kreditkarte)+NULLIFZERO(idx_ShorttermSpar)+NULLIFZERO(idx_LongtermSpar)+NULLIFZERO(idx_Bauspar)+NULLIFZERO(idx_Versicherung)+NULLIFZERO(idx_Investment)+NULLIFZERO(idx_Konsumkredit)+NULLIFZERO(idx_Wohnbaukredit)) AS prd_anteil_arbeitgeber_Investment
,idx_Konsumkredit/(NULLIFZERO(idx_giro)+NULLIFZERO(idx_kreditkarte)+NULLIFZERO(idx_ShorttermSpar)+NULLIFZERO(idx_LongtermSpar)+NULLIFZERO(idx_Bauspar)+NULLIFZERO(idx_Versicherung)+NULLIFZERO(idx_Investment)+NULLIFZERO(idx_Konsumkredit)+NULLIFZERO(idx_Wohnbaukredit)) AS prd_anteil_arbeitgeber_Konsumkredit
,idx_Wohnbaukredit/(NULLIFZERO(idx_giro)+NULLIFZERO(idx_kreditkarte)+NULLIFZERO(idx_ShorttermSpar)+NULLIFZERO(idx_LongtermSpar)+NULLIFZERO(idx_Bauspar)+NULLIFZERO(idx_Versicherung)+NULLIFZERO(idx_Investment)+NULLIFZERO(idx_Konsumkredit)+NULLIFZERO(idx_Wohnbaukredit)) AS prd_anteil_arbeitgeber_Wohnbaukredit
FROM 
da_twm_result_seg.lab_arbeitgeber_prd_anteil_kde a										
);




/*#############################################################################################

                             get  industry segment for each company from Kde_kde_rel table

#############################################################################################*/


CREATE TABLE da_twm_result_seg.lab_lu_arbeitgeber_oenace
AS
(
SEL DISTINCT TRIM(OREPLACE(b.KUNDENNAME,'*','')) AS arbeitgeber
,b.oenace_schluessel
,c.BEZEICHNUNG_DEUTSCH AS oenace_schluessel_bes
,c.HAUPTBRANCHE_DEUTSCH
FROM vb_data.LDR_KDE_KDE_REL a

LEFT JOIN vb_data.LDR_KDE_BASIS b
ON a.KUNDENNUMMER_AN = b.KUNDENNUMMER
AND a.INSTITUTSZUORDNUNG_AN = b.INSTITUTSZUORDNUNG

LEFT JOIN (SEL oenace_2008, BEZEICHNUNG_DEUTSCH ,HAUPTBRANCHE_DEUTSCH FROM vb_lookup.LU_OENACE_BRANCHEN_MACA b GROUP BY 1,2,3)c
ON b.oenace_schluessel = c.OENACE_2008
WHERE BEZIEHUNGSART = 41
AND b.DATUM_Bis = '3500-12-31'
)WITH DATA PRIMARY INDEX(arbeitgeber,oenace_schluessel);

/*#############################################################################################

                             get lookup table with all companies regardless of number employee 

#############################################################################################*/
DELETE
FROM da_twm_result_seg.lab_lu_arbeitgeber_all T 
WHERE  EXISTS (
    SEL * FROM da_twm_result_seg.lab_lu_arbeitgeber_all neu
    WHERE T.ende_beobachtung_datum = CURRENT_DATE - EXTRACT(DAY FROM CURRENT_DATE)+1
    )
;

INSERT INTO da_twm_result_seg.lab_lu_arbeitgeber_all

SEL 
a.ende_beobachtung_datum
,TRIM(A.arbeitgeber) AS arbeitgeber
,COUNT(*) AS anz_ma
FROM da_twm_result_seg.lab_arbeitgeber_gehalt_zus a --63650
GROUP BY 1,2
WHERE a.ende_beobachtung_datum = CURRENT_DATE - EXTRACT(DAY FROM CURRENT_DATE)+1;

/*#############################################################################################

                             get  industry segment for each company from lab_lu_arbeitgeber_all table

#############################################################################################*/

DELETE
FROM da_twm_result_seg.lab_lu_arbeitgeber_oenace_ext_all T 
WHERE  EXISTS (
    SEL * FROM da_twm_result_seg.lab_lu_arbeitgeber_oenace_ext_all neu
    WHERE T.ende_beobachtung_datum = CURRENT_DATE - EXTRACT(DAY FROM CURRENT_DATE)+1
    )
;

INSERT INTO da_twm_result_seg.lab_lu_arbeitgeber_oenace_ext_all

SEL
a.ende_beobachtung_datum        
,a.arbeitgeber                   
,a.anz_ma                        
 
,MAX(CASE WHEN rf = 1 THEN a.oenace_schluessel ELSE NULL end) AS oenace_schluessel
,MAX(CASE WHEN rf = 1 THEN a.oenace_schluessel_bes ELSE NULL end) AS oenace_schluessel_bes
,MAX(CASE WHEN rf = 2 THEN a.oenace_schluessel ELSE NULL end) AS oenace_schluessel_2
,MAX(CASE WHEN rf = 2 THEN a.oenace_schluessel_bes ELSE NULL end) AS oenace_schluessel_bes_2
,MAX(CASE WHEN rf = 3 THEN a.oenace_schluessel ELSE NULL end) AS oenace_schluessel_3
,MAX(CASE WHEN rf = 3 THEN a.oenace_schluessel_bes ELSE NULL end) AS oenace_schluessel_bes_3
,MAX(CASE WHEN rf = 4 THEN a.oenace_schluessel ELSE NULL end) AS oenace_schluessel_4
,MAX(CASE WHEN rf = 4 THEN a.oenace_schluessel_bes ELSE NULL end) AS oenace_schluessel_bes_4
FROM
(
SEL 
a.*
,ROW_NUMBER() OVER (PARTITION BY a.ende_beobachtung_datum,a.arbeitgeber ORDER BY a.OENACE_SCHLUESSEL ASC) AS rf
FROM
(
SEL 
a.*

,CASE WHEN TRIM(a.arbeitgeber) = 'PENSIONSVERSICHERUNGSANSTALT' THEN 'ZPENSI' ELSE b.oenace_schluessel END AS oenace_schluessel
,CASE WHEN TRIM(a.arbeitgeber) = 'PENSIONSVERSICHERUNGSANSTALT' THEN 'PENSIONSVERSICHERUNGSANSTALT' ELSE b.oenace_schluessel_bes END AS oenace_schluessel_bes

FROM 
da_twm_result_seg.lab_lu_arbeitgeber_all  a 
JOIN da_twm_result_seg.lab_lu_arbeitgeber_oenace b 
ON TRIM(A.arbeitgeber) = TRIM(b.arbeitgeber)
)a
)a
GROUP BY 1,2,3
WHERE a.ende_beobachtung_datum = CURRENT_DATE - EXTRACT(DAY FROM CURRENT_DATE)+1
;

/*#############################################################################################

                             get industry segment info for each customer

#############################################################################################*/



DELETE
FROM da_twm_result_seg.lab_arbeitgeber_gehalt_oenace T 
WHERE  EXISTS (
    SEL * FROM da_twm_result_seg.lab_arbeitgeber_gehalt_oenace neu
    WHERE T.ende_beobachtung_datum = CURRENT_DATE - EXTRACT(DAY FROM CURRENT_DATE)+1
    )
;

INSERT INTO  da_twm_result_seg.lab_arbeitgeber_gehalt_oenace

SEL a.*
, b.oenace_schluessel
, b.oenace_schluessel_bes
,CASE WHEN TRIM(a.arbeitgeber) = 'PENSIONSVERSICHERUNGSANSTALT' THEN 'PENSIONSVERSICHERUNGSANSTALT' ELSE c.HAUPTBRANCHE_DEUTSCH END AS HAUPTBRANCHE_DEUTSCH
, b.oenace_schluessel_2
, b.oenace_schluessel_bes_2
,CASE WHEN TRIM(a.arbeitgeber) = 'PENSIONSVERSICHERUNGSANSTALT' THEN 'PENSIONSVERSICHERUNGSANSTALT' ELSE c2.HAUPTBRANCHE_DEUTSCH END AS HAUPTBRANCHE_DEUTSCH_2
 ,b.oenace_schluessel_3
, b.oenace_schluessel_bes_3
,CASE WHEN TRIM(a.arbeitgeber) = 'PENSIONSVERSICHERUNGSANSTALT' THEN 'PENSIONSVERSICHERUNGSANSTALT' ELSE c3.HAUPTBRANCHE_DEUTSCH END AS HAUPTBRANCHE_DEUTSCH_3
, b.oenace_schluessel_4
, b.oenace_schluessel_bes_4
,CASE WHEN TRIM(a.arbeitgeber) = 'PENSIONSVERSICHERUNGSANSTALT' THEN 'PENSIONSVERSICHERUNGSANSTALT' ELSE c4.HAUPTBRANCHE_DEUTSCH END AS HAUPTBRANCHE_DEUTSCH_4
FROM da_twm_result_seg.lab_arbeitgeber_gehalt_zus a
LEFT JOIN da_twm_result_seg.lab_lu_arbeitgeber_oenace_ext_all b
ON TRIM(a.arbeitgeber) = b.arbeitgeber
AND a.ende_beobachtung_datum = b.ende_beobachtung_datum
LEFT JOIN
(SEL oenace_2008, HAUPTBRANCHE_DEUTSCH FROM vb_lookup.LU_OENACE_BRANCHEN_MACA b GROUP BY 1,2)c
ON b.oenace_schluessel = c.OENACE_2008
LEFT JOIN
(SEL oenace_2008, HAUPTBRANCHE_DEUTSCH FROM vb_lookup.LU_OENACE_BRANCHEN_MACA b GROUP BY 1,2)c2
ON b.oenace_schluessel_2 = c2.OENACE_2008
LEFT JOIN
(SEL oenace_2008, HAUPTBRANCHE_DEUTSCH FROM vb_lookup.LU_OENACE_BRANCHEN_MACA b GROUP BY 1,2)c3
ON b.oenace_schluessel_3 = c3.OENACE_2008
LEFT JOIN
(SEL oenace_2008, HAUPTBRANCHE_DEUTSCH FROM vb_lookup.LU_OENACE_BRANCHEN_MACA b GROUP BY 1,2)c4
ON b.oenace_schluessel_4 = c4.OENACE_2008
WHERE a.ende_beobachtung_datum = CURRENT_DATE - EXTRACT(DAY FROM CURRENT_DATE)+1
;


/*  drop staging table s */
DROP TABLE da_twm_result_seg.lab_lu_arbeitgeber_oenace;
DROP TABLE da_twm_result_seg.lab_arbeitgeber_gehalt_zus;
DROP TABLE da_twm_result_seg.lab_arbeitgeber_gehalt;

/*#############################################################################################

                             get  product info for each industry segment main segment

#############################################################################################*/

DELETE
FROM da_twm_result_seg.lab_lu_branche_prd_anteil T 
WHERE  EXISTS (
    SEL * FROM da_twm_result_seg.lab_lu_branche_prd_anteil neu
    WHERE T.ende_beobachtung_datum = CURRENT_DATE - EXTRACT(DAY FROM CURRENT_DATE)+1
    )
;

INSERT INTO  da_twm_result_seg.lab_lu_branche_prd_anteil

SEL 
a.ende_beobachtung_datum
,hauptbranche_deutsch
,COUNT(*) AS anz_kde_branche
,SUM(GIROKONTOINHABER) / COUNT(*) AS giro_branche
,SUM(sparkunden_kurzfristig) / COUNT(*) AS shorttermspar_branche
,SUM(sparkunden_langfristig) / COUNT(*) AS longtermspar_branche
,SUM(konsumkreditinhaber) / COUNT(*) AS konsumkredit_branche
,SUM(wohnbaukreditinhaber) / COUNT(*) AS wohnbaukredit_branche
,SUM(versicherungsinhaber) / COUNT(*) AS versicherung_branche
,SUM(bausparinhaber) / COUNT(*) AS bauspar_branche
,SUM(wertpapierinhaber) / COUNT(*) AS wertpapier_branche
,SUM(kreditkarteninhaber) / COUNT(*) AS kreditkarte_branche
,ZEROIFNULL(CAST(ZEROIFNULL(giro_branche)*anz_kde_branche +ZEROIFNULL(shorttermspar_branche)*anz_kde_branche +ZEROIFNULL(longtermspar_branche)*anz_kde_branche +ZEROIFNULL(konsumkredit_branche)*anz_kde_branche +ZEROIFNULL(konsumkredit_branche)*anz_kde_branche +ZEROIFNULL(wohnbaukredit_branche)*anz_kde_branche +ZEROIFNULL(versicherung_branche)*anz_kde_branche +ZEROIFNULL(bauspar_branche)*anz_kde_branche +ZEROIFNULL(wertpapier_branche) +ZEROIFNULL(kreditkarte_branche) AS FLOAT))
/NULLIFZERO(CAST(anz_kde_branche AS FLOAT)) AS prd_saett_branche
,giro_branche/prd_saett_branche AS giro_rel_branche
,shorttermspar_branche/prd_saett_branche AS shorttermspar_rel_branche
,longtermspar_branche/prd_saett_branche AS longtermspar_rel_branche
,konsumkredit_branche/prd_saett_branche AS konsumkredit_rel_branche
,wohnbaukredit_branche/prd_saett_branche AS wohnbaukredit_rel_branche
,versicherung_branche/prd_saett_branche AS versicherung_rel_branche
,bauspar_branche/prd_saett_branche AS bauspar_rel_branche
,wertpapier_branche/prd_saett_branche AS wertpapier_rel_branche
,kreditkarte_branche/prd_saett_branche AS kreditkarte_rel_branche
FROM
(
SEL 
a.ende_beobachtung_datum
,hauptbranche_deutsch
,a.kundennummer
,a.institutszuordnung
,MAX(GIROKONTOINHABER)  AS GIROKONTOINHABER
,MAX(sparkunden_kurzfristig)  AS sparkunden_kurzfristig
,MAX(sparkunden_langfristig)  AS sparkunden_langfristig
,MAX(konsumkreditinhaber)  AS konsumkreditinhaber
,MAX(wohnbaukreditinhaber)  AS wohnbaukreditinhaber
,MAX(versicherungsinhaber)  AS versicherungsinhaber
,MAX(bausparinhaber)  AS bausparinhaber
,MAX(wertpapierinhaber)  AS wertpapierinhaber
,MAX(kreditkarteninhaber)  AS kreditkarteninhaber
FROM 
da_twm_result_seg.lab_arbeitgeber_gehalt_oenace a
LEFT JOIN vm_acrm_reporting.DASHBOARD b
ON a.kundennummer = b.KUNDENNUMMER
AND a.institutszuordnung = b.INSTITUTSZUORDNUNG
AND a.ende_beobachtung_datum >= b.ENDE_BEOBACHTUNG_DATUM
GROUP BY 1,2,3,4
)a GROUP BY 1,2
WHERE a.ende_beobachtung_datum = CURRENT_DATE - EXTRACT(DAY FROM CURRENT_DATE)+1
;


/*#############################################################################################

                             get  product info for each industry subsegment

#############################################################################################*/


DELETE
FROM da_twm_result_seg.lab_lu_oenace3Stell_prd_anteil T 
WHERE  EXISTS (
    SEL * FROM da_twm_result_seg.lab_lu_oenace3Stell_prd_anteil neu
    WHERE T.ende_beobachtung_datum = CURRENT_DATE - EXTRACT(DAY FROM CURRENT_DATE)+1
    )
;

INSERT INTO  da_twm_result_seg.lab_lu_oenace3Stell_prd_anteil

SEL 
a.ende_beobachtung_datum
,oenace_sub_kat
,oenace_sub_bes
,COUNT(*) AS anz_kde_subbranche
,SUM(GIROKONTOINHABER) / NULLIFZERO(COUNT(*)) AS giro_subbranche
,SUM(sparkunden_kurzfristig) / NULLIFZERO(COUNT(*)) AS shorttermspar_subbranche
,SUM(sparkunden_langfristig) / NULLIFZERO(COUNT(*)) AS longtermspar_subbranche
,SUM(konsumkreditinhaber) / NULLIFZERO(COUNT(*)) AS konsumkredit_subbranche
,SUM(wohnbaukreditinhaber) / NULLIFZERO(COUNT(*)) AS wohnbaukredit_subbranche
,SUM(versicherungsinhaber) / NULLIFZERO(COUNT(*)) AS versicherung_subbranche
,SUM(bausparinhaber) / NULLIFZERO(COUNT(*)) AS bauspar_subbranche
,SUM(wertpapierinhaber) / NULLIFZERO(COUNT(*)) AS wertpapier_subbranche
,SUM(kreditkarteninhaber) / NULLIFZERO(COUNT(*)) AS kreditkarte_subbranche
,ZEROIFNULL(CAST(ZEROIFNULL(giro_subbranche)*anz_kde_subbranche +ZEROIFNULL(shorttermspar_subbranche)*anz_kde_subbranche +ZEROIFNULL(longtermspar_subbranche)*anz_kde_subbranche +ZEROIFNULL(konsumkredit_subbranche)*anz_kde_subbranche +ZEROIFNULL(konsumkredit_subbranche)*anz_kde_subbranche +ZEROIFNULL(wohnbaukredit_subbranche)*anz_kde_subbranche +ZEROIFNULL(versicherung_subbranche)*anz_kde_subbranche +ZEROIFNULL(bauspar_subbranche)*anz_kde_subbranche +ZEROIFNULL(wertpapier_subbranche) +ZEROIFNULL(kreditkarte_subbranche) AS FLOAT))
/NULLIFZERO(CAST(anz_kde_subbranche AS FLOAT)) AS prd_saett_subbranche
,giro_subbranche/NULLIFZERO(prd_saett_subbranche) AS giro_rel_subbranche
,shorttermspar_subbranche/NULLIFZERO(prd_saett_subbranche) AS shorttermspar_rel_subbranche
,longtermspar_subbranche/NULLIFZERO(prd_saett_subbranche) AS longtermspar_rel_subbranche
,konsumkredit_subbranche/NULLIFZERO(prd_saett_subbranche) AS konsumkredit_rel_subbranche
,wohnbaukredit_subbranche/NULLIFZERO(prd_saett_subbranche) AS wohnbaukredit_rel_subbranche
,versicherung_subbranche/NULLIFZERO(prd_saett_subbranche) AS versicherung_rel_subbranche
,bauspar_subbranche/NULLIFZERO(prd_saett_subbranche) AS bauspar_rel_subbranche
,wertpapier_subbranche/NULLIFZERO(prd_saett_subbranche) AS wertpapier_rel_subbranche
,kreditkarte_subbranche/NULLIFZERO(prd_saett_subbranche) AS kreditkarte_rel_subbranche
FROM
(
SEL 
a.ende_beobachtung_datum
,CASE WHEN hauptbranche_deutsch IN( 'Öffentliche Hand','Handel','Verkehr & Transport' ) THEN  SUBSTR(oenace_schluessel,1,4)
ELSE SUBSTR(oenace_schluessel,1,3)  END AS oenace_sub_kat
,hauptbranche_deutsch||'_'||oenace_sub_kat AS oenace_sub_bes
,a.kundennummer
,a.institutszuordnung
,MAX(GIROKONTOINHABER)  AS GIROKONTOINHABER
,MAX(sparkunden_kurzfristig)  AS sparkunden_kurzfristig
,MAX(sparkunden_langfristig)  AS sparkunden_langfristig
,MAX(konsumkreditinhaber)  AS konsumkreditinhaber
,MAX(wohnbaukreditinhaber)  AS wohnbaukreditinhaber
,MAX(versicherungsinhaber)  AS versicherungsinhaber
,MAX(bausparinhaber)  AS bausparinhaber
,MAX(wertpapierinhaber)  AS wertpapierinhaber
,MAX(kreditkarteninhaber)  AS kreditkarteninhaber
FROM 
da_twm_result_seg.lab_arbeitgeber_gehalt_oenace a
LEFT JOIN vm_acrm_reporting.DASHBOARD b
ON a.kundennummer = b.KUNDENNUMMER
AND a.institutszuordnung = b.INSTITUTSZUORDNUNG
AND a.ende_beobachtung_datum >= b.ENDE_BEOBACHTUNG_DATUM
GROUP BY 1,2,3,4,5
)a GROUP BY 1,2,3
WHERE a.ende_beobachtung_datum = CURRENT_DATE - EXTRACT(DAY FROM CURRENT_DATE)+1
;



/*#############################################################################################

                             get  industry segment for each customer

#############################################################################################*/

DELETE
FROM da_twm_result_seg.lab_lu_oenace_prd_anteil T 
WHERE  EXISTS (
    SEL * FROM da_twm_result_seg.lab_lu_oenace_prd_anteil neu
    WHERE T.ende_beobachtung_datum = CURRENT_DATE - EXTRACT(DAY FROM CURRENT_DATE)+1
    )
;

INSERT INTO  da_twm_result_seg.lab_lu_oenace_prd_anteil

SEL 
a.ende_beobachtung_datum
,oenace_schluessel
,oenace_schluessel_bes
,COUNT(*) AS anz_kde_oenace_detail
,SUM(GIROKONTOINHABER) / NULLIFZERO(COUNT(*)) AS giro_oenace_detail
,SUM(sparkunden_kurzfristig) / NULLIFZERO(COUNT(*)) AS shorttermspar_oenace_detail
,SUM(sparkunden_langfristig) / NULLIFZERO(COUNT(*)) AS longtermspar_oenace_detail
,SUM(konsumkreditinhaber) / NULLIFZERO(COUNT(*)) AS konsumkredit_oenace_detail
,SUM(wohnbaukreditinhaber) / NULLIFZERO(COUNT(*)) AS wohnbaukredit_oenace_detail
,SUM(versicherungsinhaber) / NULLIFZERO(COUNT(*)) AS versicherung_oenace_detail
,SUM(bausparinhaber) / NULLIFZERO(COUNT(*)) AS bauspar_oenace_detail
,SUM(wertpapierinhaber) / NULLIFZERO(COUNT(*)) AS wertpapier_oenace_detail
,SUM(kreditkarteninhaber) / NULLIFZERO(COUNT(*)) AS kreditkarte_oenace_detail
,ZEROIFNULL(CAST(ZEROIFNULL(giro_oenace_detail)*anz_kde_oenace_detail +ZEROIFNULL(shorttermspar_oenace_detail)*anz_kde_oenace_detail +ZEROIFNULL(longtermspar_oenace_detail)*anz_kde_oenace_detail +ZEROIFNULL(konsumkredit_oenace_detail)*anz_kde_oenace_detail +ZEROIFNULL(konsumkredit_oenace_detail)*anz_kde_oenace_detail +ZEROIFNULL(wohnbaukredit_oenace_detail)*anz_kde_oenace_detail +ZEROIFNULL(versicherung_oenace_detail)*anz_kde_oenace_detail +ZEROIFNULL(bauspar_oenace_detail)*anz_kde_oenace_detail +ZEROIFNULL(wertpapier_oenace_detail) +ZEROIFNULL(kreditkarte_oenace_detail) AS FLOAT))
/NULLIFZERO(CAST(anz_kde_oenace_detail AS FLOAT)) AS prd_saett_oenace_detail
,giro_oenace_detail/NULLIFZERO(prd_saett_oenace_detail) AS giro_rel_oenace_detail
,shorttermspar_oenace_detail/NULLIFZERO(prd_saett_oenace_detail) AS shorttermspar_rel_oenace_detail
,longtermspar_oenace_detail/NULLIFZERO(prd_saett_oenace_detail) AS longtermspar_rel_oenace_detail
,konsumkredit_oenace_detail/NULLIFZERO(prd_saett_oenace_detail) AS konsumkredit_rel_oenace_detail
,wohnbaukredit_oenace_detail/NULLIFZERO(prd_saett_oenace_detail) AS wohnbaukredit_rel_oenace_detail
,versicherung_oenace_detail/NULLIFZERO(prd_saett_oenace_detail) AS versicherung_rel_oenace_detail
,bauspar_oenace_detail/NULLIFZERO(prd_saett_oenace_detail) AS bauspar_rel_oenace_detail
,wertpapier_oenace_detail/NULLIFZERO(prd_saett_oenace_detail) AS wertpapier_rel_oenace_detail
,kreditkarte_oenace_detail/NULLIFZERO(prd_saett_oenace_detail) AS kreditkarte_rel_oenace_detail
FROM
(
SEL 
a.ende_beobachtung_datum
,oenace_schluessel
,oenace_schluessel_bes
,a.kundennummer
,a.institutszuordnung
,MAX(GIROKONTOINHABER)  AS GIROKONTOINHABER
,MAX(sparkunden_kurzfristig)  AS sparkunden_kurzfristig
,MAX(sparkunden_langfristig)  AS sparkunden_langfristig
,MAX(konsumkreditinhaber)  AS konsumkreditinhaber
,MAX(wohnbaukreditinhaber)  AS wohnbaukreditinhaber
,MAX(versicherungsinhaber)  AS versicherungsinhaber
,MAX(bausparinhaber)  AS bausparinhaber
,MAX(wertpapierinhaber)  AS wertpapierinhaber
,MAX(kreditkarteninhaber)  AS kreditkarteninhaber
FROM 
da_twm_result_seg.lab_arbeitgeber_gehalt_oenace a
LEFT JOIN vm_acrm_reporting.DASHBOARD b
ON a.kundennummer = b.KUNDENNUMMER
AND a.institutszuordnung = b.INSTITUTSZUORDNUNG
AND a.ende_beobachtung_datum >= b.ENDE_BEOBACHTUNG_DATUM
GROUP BY 1,2,3,4,5
)a GROUP BY 1,2,3
WHERE a.ende_beobachtung_datum = CURRENT_DATE - EXTRACT(DAY FROM CURRENT_DATE)+1
;

/*#############################################################################################

                             get industry segment info for each customer

#############################################################################################*/





REPLACE VIEW da_twm_result_seg.lab_arbeitgeber_branche_prd_kpi
AS

SEL 
a.ende_beobachtung_datum
,a.kundennummer
,a.institutszuordnung
,a.HAUPTBRANCHE_DEUTSCH          
,b.anz_kde_branche               
,b.giro_branche                  
,b.shorttermspar_branche         
,b.longtermspar_branche          
,b.konsumkredit_branche          
,b.wohnbaukredit_branche         
,b.versicherung_branche          
,b.bauspar_branche               
,b.wertpapier_branche            
,b.kreditkarte_branche           
,b.prd_saett_branche             
,b.giro_rel_branche              
,b.shorttermspar_rel_branche     
,b.longtermspar_rel_branche      
,b.konsumkredit_rel_branche      
,b.wohnbaukredit_rel_branche     
,b.versicherung_rel_branche      
,b.bauspar_rel_branche           
,b.wertpapier_rel_branche        
,b.kreditkarte_rel_branche       

,c.oenace_sub_kat                
,c.oenace_sub_bes                
,c.anz_kde_subbranche            
,c.giro_subbranche               
,c.shorttermspar_subbranche      
,c.longtermspar_subbranche       
,c.konsumkredit_subbranche       
,c.wohnbaukredit_subbranche      
,c.versicherung_subbranche       
,c.bauspar_subbranche            
,c.wertpapier_subbranche         
,c.kreditkarte_subbranche        
,c.prd_saett_subbranche          
,c.giro_rel_subbranche           
,c.shorttermspar_rel_subbranche  
,c.longtermspar_rel_subbranche   
,c.konsumkredit_rel_subbranche   
,c.wohnbaukredit_rel_subbranche  
,c.versicherung_rel_subbranche   
,c.bauspar_rel_subbranche        
,c.wertpapier_rel_subbranche     
,c.kreditkarte_rel_subbranche    

,d.anz_kde_oenace_detail         
,d.giro_oenace_detail            
,d.shorttermspar_oenace_detail   
,d.longtermspar_oenace_detail    
,d.konsumkredit_oenace_detail    
,d.wohnbaukredit_oenace_detail   
,d.versicherung_oenace_detail    
,d.bauspar_oenace_detail         
,d.wertpapier_oenace_detail      
,d.kreditkarte_oenace_detail     
,d.prd_saett_oenace_detail       
,d.giro_rel_oenace_detail        
,d.shorttermspar_rel_oenace_detail
,d.longtermspar_rel_oenace_detail
,d.konsumkredit_rel_oenace_detail
,d.wohnbaukredit_rel_oenace_detail
,d.versicherung_rel_oenace_detail
,d.bauspar_rel_oenace_detail     
,d.wertpapier_rel_oenace_detail  
,d.kreditkarte_rel_oenace_detail 

FROM da_twm_result_seg.lab_arbeitgeber_gehalt_oenace a

LEFT JOIN da_twm_result_seg.lab_lu_branche_prd_anteil b
ON a.hauptbranche_deutsch = b.hauptbranche_deutsch
AND a.ende_beobachtung_datum = b.ende_beobachtung_datum

LEFT JOIN da_twm_result_seg.lab_lu_oenace3Stell_prd_anteil c
ON CASE WHEN a.hauptbranche_deutsch IN( 'Öffentliche Hand','Handel','Verkehr & Transport' ) THEN  SUBSTR(a.oenace_schluessel,1,4)
ELSE SUBSTR(a.oenace_schluessel,1,3)  END = c.oenace_sub_kat
AND a.ende_beobachtung_datum = c.ende_beobachtung_datum

LEFT JOIN da_twm_result_seg.lab_lu_oenace_prd_anteil d
ON a.oenace_schluessel = d.oenace_schluessel
AND a.ende_beobachtung_datum = d.ende_beobachtung_datum
;






