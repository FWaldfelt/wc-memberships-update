/**
 * Updates WC Memberships to the correct end dates based on the subscription.
 * Author: Fredrik Waldfelt (fredrik@waldfelt.com)
 * Date: 2020-01.24
 **/
 
DROP PROCEDURE IF EXISTS set_subscription_schedule_end;
DROP PROCEDURE IF EXISTS set_membership_update_end;
DROP PROCEDURE IF EXISTS update_membership_subscription;

DELIMITER //
CREATE PROCEDURE `update_wc_end_dates` ()
BEGIN
	DECLARE p_id 	INT DEFAULT 0;
	DECLARE done	INT DEFAULT false;

	DECLARE zero_end_date CURSOR FOR 
		SELECT sub.meta_value FROM wp_postmeta as sub
		INNER JOIN (
			SELECT post_id FROM wp_postmeta WHERE meta_key = '_end_date' AND meta_value = ''
		) AS ms
		ON sub.post_id = ms.post_id  AND sub.meta_key = '_subscription_id'
        FOR UPDATE;

	DECLARE CONTINUE HANDLER FOR NOT FOUND SET done=true;
    START TRANSACTION;
    OPEN zero_end_date;
		get_all: LOOP
        FETCH zero_end_date INTO p_id;
        IF done THEN
			LEAVE get_all;
		END IF;
		
        -- Update subscriptions end dates from next payment date
		call set_subscription_schedule_end(p_id);
        -- Update membership end dates from subscriptions end dates
		call set_membership_update_end(p_id);
            
		END LOOP;
    CLOSE zero_end_date;
    ROLLBACK;
    -- COMMIT;
end; //


DELIMITER //
CREATE PROCEDURE `set_subscription_schedule_end` (IN p_id int)
BEGIN
UPDATE wp_postmeta 
	SET meta_value = 
    (SELECT s.meta_value
		FROM (SELECT meta_value FROM wp_postmeta WHERE meta_key = '_schedule_next_payment' and post_id = p_id) 
    AS s)
    WHERE meta_key = '_schedule_end' AND meta_value = '0' and post_id= p_id;
END //

DELIMITER //
CREATE PROCEDURE `set_membership_update_end` (IN p_id int)
BEGIN
UPDATE wp_postmeta 
	SET meta_value = 
    (SELECT s.meta_value
		FROM (SELECT meta_value FROM wp_postmeta WHERE meta_key = '_schedule_next_payment' and post_id = p_id) 
    AS s)
    WHERE meta_key = '_end_date' AND meta_value = '' and post_id =
		(SELECT m.post_id
			FROM (SELECT post_id FROM wp_postmeta WHERE meta_key = '_subscription_id' and meta_value = p_id)
		as m);
END //
