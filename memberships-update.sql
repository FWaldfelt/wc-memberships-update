/**
 * Updates WC Memberships to the correct end dates based on the subscription.
 * Author: Fredrik Waldfelt (fredrik@waldfelt.com)
 * Date: 2020-01.24
 *
 * Usage; Add procedures to the database.
 *
 * call update_wc_dates(memberships_plan_id INT); Updates both start and end date of all memberships in memberships plan with a certain ID.
 * call update_wc_dates(null); Updates both start and end date of all memberships in all memberships plan.
 *
 * call update_wc_end_dates(memberships_plan_id INT); Updates end date of all memberships in memberships plan with a certain ID.
 * call update_wc_dates(null); Updates end date of all memberships in all memberships plan.
 *
 * Drop all procedures when done.
 **/
 
DROP PROCEDURE IF EXISTS set_subscription_schedule_end;
DROP PROCEDURE IF EXISTS set_membership_update_start;
DROP PROCEDURE IF EXISTS set_membership_update_end;
DROP PROCEDURE IF EXISTS update_wc_end_dates;
DROP PROCEDURE IF EXISTS update_wc_dates;

/** 
 * Updates WC Memberships start and end dates to be the same as the end date of the subscription.
 *
 * @param memberships_plan_id INT Memberships Plan ID where members end dates should be updated. If NULL then all members updates.
 */
DELIMITER //
CREATE PROCEDURE `update_wc_dates` (IN memberships_plan_id INT)
BEGIN
	DECLARE p_id 	INT DEFAULT 0;
	DECLARE done	INT DEFAULT false;
    DECLARE mp_id	VARCHAR(20) DEFAULT '%';

	DECLARE members CURSOR FOR 
		SELECT sub.meta_value FROM wp_postmeta as sub
			INNER JOIN (
				SELECT ID FROM wp_posts WHERE post_type = 'wc_user_membership' and `post_parent` LIKE mp_id
			) AS post
			ON sub.post_id = post.ID  AND sub.meta_key = '_subscription_id'
			FOR UPDATE;

	DECLARE CONTINUE HANDLER FOR NOT FOUND SET done=true;
	IF memberships_plan_id IS NOT NULL THEN
		SET mp_ID = memberships_plan_id;
	END IF;
    
    START TRANSACTION;
    OPEN members;
		get_all: LOOP
        FETCH members INTO p_id;
        IF done THEN
			LEAVE get_all;
		END IF;
        -- Update subscriptions end dates from next payment date.
		call set_subscription_schedule_end(p_id);
        -- Update membership end dates from subscriptions end date.
		call set_membership_update_end(p_id);
        -- Update memberships start dates rom subscription start date.
        call set_membership_update_start(p_id);
            
		END LOOP;
    CLOSE members;
    COMMIT;
end; //



/** 
 * Updates WC Memberships end dates to be the same as the end date of the subscription.
 *
 * @param memberships_plan_id INT Memberships Plan ID where members end dates should be updated. If NULL then all members updates.
 */
DELIMITER //
CREATE PROCEDURE `update_wc_end_dates` (IN memberships_plan_id INT)
BEGIN
	DECLARE p_id 	INT DEFAULT 0;
	DECLARE done	INT DEFAULT false;

	DECLARE members CURSOR FOR 
		SELECT sub.meta_value FROM wp_postmeta as sub
			INNER JOIN (
				SELECT ID FROM wp_posts WHERE post_type = 'wc_user_membership' and `post_parent` LIKE mp_id
			) AS post
			ON sub.post_id = post.ID  AND sub.meta_key = '_subscription_id'
			FOR UPDATE;

	DECLARE CONTINUE HANDLER FOR NOT FOUND SET done=true;
    
	IF memberships_plan_id IS NOT NULL THEN
		SET mp_ID = memberships_plan_id;
	END IF;

    START TRANSACTION;
    OPEN members;
		get_all: LOOP
        FETCH members INTO p_id;
        IF done THEN
			LEAVE get_all;
		END IF;
		
        -- Update subscriptions end dates from next payment date
		call set_subscription_schedule_end(p_id);
        -- Update membership end dates from subscriptions end dates
		call set_membership_update_end(p_id);
            
		END LOOP;
    CLOSE members;
    COMMIT;
end; //


/** 
 * Updates WC Subscription end date to next_payment date. Needind if subscription is changed from never expires.
 */
DELIMITER //
CREATE PROCEDURE `set_subscription_schedule_end` (IN p_id INT)
BEGIN
UPDATE wp_postmeta 
	SET meta_value = 
    (SELECT s.meta_value
		FROM (SELECT meta_value FROM wp_postmeta WHERE meta_key = '_schedule_next_payment' and post_id = p_id) 
    AS s)
    WHERE meta_key = '_schedule_end' AND meta_value = '0' and post_id= p_id;
END //

/** 
 * Updates WC Memberships end dates to be the same as the end date of the subscription.
 */
DELIMITER //
CREATE PROCEDURE `set_membership_update_end` (IN p_id INT)
BEGIN
UPDATE wp_postmeta 
	SET meta_value = 
    (SELECT s.meta_value
		FROM (SELECT meta_value FROM wp_postmeta WHERE meta_key = '_schedule_next_payment' and post_id = p_id) 
    AS s)
    WHERE meta_key = '_end_date' and post_id =
		(SELECT m.post_id
			FROM (SELECT post_id FROM wp_postmeta WHERE meta_key = '_subscription_id' and meta_value = p_id)
		as m);
END //

/** 
 * Updates WC Memberships start dates to be the same as the start date of the subscription.
 */
DELIMITER //
CREATE PROCEDURE `set_membership_update_start` (IN p_id INT)
BEGIN
UPDATE wp_postmeta 
	SET meta_value = 
    (SELECT s.meta_value
		FROM (SELECT meta_value FROM wp_postmeta WHERE meta_key = '_schedule_start' and post_id = p_id) 
    AS s)
    WHERE meta_key = '_start_date' and post_id =
		(SELECT m.post_id
			FROM (SELECT post_id FROM wp_postmeta WHERE meta_key = '_subscription_id' and meta_value = p_id)
		as m);
END //