CREATE TABLE IF NOT EXISTS pan_dataset
(
	pan_number text
);

-- imported 10,000 records

SELECT * FROM pan_dataset;     -- 10000 total records

----     Cleaning the records before validating    ----

-- 1: Indetify and handle missing data

SELECT * FROM pan_dataset WHERE pan_number is null;      -- 965 null records


-- 2: Check for duplicates

SELECT pan_number, COUNT(1)                              -- 6 different type of  duplicate records
FROM pan_dataset
GROUP BY pan_number
HAVING COUNT(1)>1;


-- 3: Handling leading and trailing spaces

SELECT * FROM pan_dataset                                -- 9 records with leading or trailing spaces
WHERE pan_number != trim(pan_number);  


-- 4: Correct letter case           

SELECT * FROM pan_dataset                                -- 990 records with small case letters 
WHERE pan_number != upper(pan_number);


---- Filtering out all undesired records ----

SELECT * FROM pan_dataset WHERE pan_number is not null;


SELECT DISTINCT pan_number
FROM pan_dataset
WHERE pan_number is not null;

SELECT DISTINCT TRIM(pan_number)
FROM pan_dataset
WHERE TRIM(pan_number) IS NOT null AND TRIM(pan_number) != '';

SELECT DISTINCT UPPER(TRIM(pan_number))
FROM pan_dataset
WHERE TRIM(pan_number) IS NOT null AND TRIM(pan_number) != '';


-- Function to check whether any two adjescent characters are the same or not:

CREATE OR REPLACE FUNCTION check_adjecent_characters(str TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    i INT;
BEGIN
    FOR i IN 1 .. LENGTH(str) - 1 LOOP
        IF SUBSTRING(str, i, 1) = SUBSTRING(str, i+1, 1) THEN
            RETURN TRUE;  -- two adjecent characters were fiund to be the same
        END IF;
    END LOOP;
    RETURN FALSE;   -- no two two adjecent characters were found to be same
END;
$$;


-- Function to check whether whole text/number forms any sequence or not:

CREATE OR REPLACE FUNCTION has_sequence(str TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    i INT;
BEGIN
    FOR i IN 1 .. LENGTH(str) - 1 LOOP
        IF ASCII(SUBSTRING(str, i+1, 1)) - ASCII(SUBSTRING(str, i, 1)) != 1 THEN
            RETURN FALSE;  -- no sequence found
        END IF;
    END LOOP;
    RETURN TRUE;   -- sequence was found
END;
$$;


-- Regular Expression to check the length, pattern and structure:
SELECT * FROM pan_dataset
WHERE pan_number ~ '^[A-Z]{5}[0-9]{4}[A-Z]$'; 
                                -- first 5 characters are upper case letters and
								-- next 4 are numbers,last one is upper case letter
	
	
--Valid and Invalid categorization
WITH clean_data AS
	(SELECT DISTINCT UPPER(TRIM(pan_number)) as pan_number
	FROM pan_dataset
	WHERE TRIM(pan_number) IS NOT null AND TRIM(pan_number) != '')
SELECT * 
FROM clean_data
WHERE pan_number ~ '^[A-Z]{5}[0-9]{4}[A-Z]$'
AND check_adjecent_characters(pan_number) = FALSE
AND has_sequence(SUBSTRING(pan_number, 1, 5)) = FALSE
AND has_sequence(SUBSTRING(pan_number, 6, 4)) = FALSE;
								-- returns PAN numbers that are valid as per convention
								
-- But we dpn't need to show only the valid ones, we also need to have th einvalid ones
-- So, instead of fiktering out the invalid ones, we shall use CTE for valid ones

WITH cte_cleaned_pan AS
		(SELECT DISTINCT UPPER(TRIM(pan_number)) as pan_number
		FROM pan_dataset
		WHERE TRIM(pan_number) IS NOT null AND TRIM(pan_number) != ''),
		
	cte_valid_pan AS
		(SELECT * 
		FROM cte_cleaned_pan
		WHERE pan_number ~ '^[A-Z]{5}[0-9]{4}[A-Z]$'
		AND check_adjecent_characters(pan_number) = FALSE
		AND has_sequence(SUBSTRING(pan_number, 1, 5)) = FALSE
		AND has_sequence(SUBSTRING(pan_number, 6, 4)) = FALSE)
		
SELECT cln.pan_number,
	CASE WHEN vld.pan_number IS NOT NULL
		THEN 'Valid PAN'
		ELSE 'Invalid PAN'
	END AS Status
FROM cte_cleaned_pan AS cln 
LEFT JOIN cte_valid_pan vld
ON cln.pan_number = vld.pan_number;			
								-- This will assign Valid or Invalid to the PANs
								
-- As per the requirement we need to display the valids, invalids and cleaned up number of PAN Cards
-- So let's create a view and show everything in order

CREATE OR REPLACE VIEW  view_valid_invalid AS
		(WITH cte_cleaned_pan AS
				(SELECT DISTINCT UPPER(TRIM(pan_number)) as pan_number
				FROM pan_dataset
				WHERE TRIM(pan_number) IS NOT null AND TRIM(pan_number) != ''),

			cte_valid_pan AS
				(SELECT * 
				FROM cte_cleaned_pan
				WHERE pan_number ~ '^[A-Z]{5}[0-9]{4}[A-Z]$'
				AND check_adjecent_characters(pan_number) = FALSE
				AND has_sequence(SUBSTRING(pan_number, 1, 5)) = FALSE
				AND has_sequence(SUBSTRING(pan_number, 6, 4)) = FALSE)

		SELECT cln.pan_number,
			CASE WHEN vld.pan_number IS NOT NULL
				THEN 'Valid PAN'
				ELSE 'Invalid PAN'
			END AS Status
		FROM cte_cleaned_pan AS cln 
		LEFT JOIN cte_valid_pan vld
		ON cln.pan_number = vld.pan_number)

SELECT * FROM view_valid_invalid;;


-- Summary report:

WITH cte AS 
			(SELECT 
					(SELECT COUNT(*) FROM pan_dataset) AS Total_Records,
					COUNT(*) FILTER (WHERE Status = 'Valid PAN') AS Total_valid_PANs,
					COUNT(*) FILTER (WHERE Status = 'Invalid PAN') AS Total_invalid_PANs
			FROM view_valid_invalid)
SELECT Total_Records, Total_valid_PANs, Total_invalid_PANs,
(Total_Records - (Total_valid_PANs + Total_invalid_PANs)) AS Filtered_out_PANs
FROM cte;