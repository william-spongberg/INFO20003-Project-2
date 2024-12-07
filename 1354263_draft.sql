-- 1
SELECT v.ID AS videoID,
	   v.title
FROM video v
LEFT JOIN annotation a ON v.ID = a.sourceVideoID -- videos with annotations
WHERE a.destinationVideoID IS NULL -- but no annotation linking to another video
GROUP BY videoID,
		 v.title;

-- 2
SELECT r.videoID AS videoID,
       u.username,
       r.ratingTime AS ratingTimestamp
FROM rating r
INNER JOIN user u ON r.linkedUser = u.ID -- get ratings with corresponding user
ORDER BY r.ratingTime DESC -- order so latest first
LIMIT 1; -- grab latest

-- 3
SELECT v.ID AS videoID, v.title
FROM video v
JOIN cocreator c ON v.ID = c.videoID -- get creatorIDs from videos
JOIN content_creator cc ON c.creatorID = cc.ID -- get content creators
WHERE cc.screenName = 'TaylorSwiftOfficial' -- on conditions
	  AND v.viewCount >= 1000000;

-- 4
SELECT v.ID AS videoID,
       v.title,
       COUNT(a.destinationVideoID) AS linkedCount
FROM video v
LEFT JOIN annotation a ON v.ID = a.destinationVideoID -- is linked to
GROUP BY v.ID , v.title
HAVING linkedCount = ( -- with max linked to count
SELECT MAX(linkedCount)
    FROM (
		SELECT COUNT(destinationVideoID) AS linkedCount -- get all linked to counts
        FROM annotation
        GROUP BY destinationVideoID
	) AS counts
);

-- 5
SELECT v.id AS videoID,
       v.uploaded AS uploadDatetime,
       COUNT(r.videoID) AS ratingCount
FROM video v
JOIN video_hashtag vh ON v.id = vh.videoID -- valid hashtag
JOIN hashtag h ON vh.hashtagID = h.id -- get video hashtagID
LEFT JOIN rating r ON v.id = r.videoID -- valid rating
WHERE h.tag = '#memes' -- on condition
GROUP BY v.id , v.uploaded
HAVING ratingCount >= 3; -- on condition

-- 6
SELECT u.username,
	   cc.realName,
	   cc.screenName
       -- ,u.reputation
FROM user u
JOIN content_creator cc ON u.id = cc.linkedUser -- is also a user
WHERE u.reputation < 50 -- on condition
AND ( -- has at least 3 videos
    SELECT COUNT(DISTINCT c.videoID)
    FROM cocreator c
    WHERE c.creatorID = cc.id
) >= 3
AND ( -- has at least 6 ratings on these videos
    SELECT COUNT(DISTINCT r.videoID)
    FROM rating r
    WHERE r.videoID IN (
		SELECT DISTINCT c.videoID
        FROM cocreator c
        WHERE c.creatorID = cc.id
	)
) >= 6;

-- 7
SELECT h.tag AS hashtag,
       COUNT(*) AS commentCount
FROM video_hashtag vh
JOIN rating r ON vh.videoID = r.videoID -- valid rating
JOIN video v ON vh.videoID = v.ID -- valid video
JOIN hashtag h ON vh.hashtagID = h.ID -- valid hashtag
WHERE LOWER(r.comment) LIKE '%thank you%' -- on condition
	  OR LOWER(r.comment) LIKE '%well done%'
GROUP BY h.tag
HAVING commentCount = ( -- with max comment count
SELECT MAX(commentCount)
    FROM (
        SELECT COUNT(*) AS commentCount -- get all comment counts
        FROM video_hashtag vh
        JOIN rating r ON vh.videoID = r.videoID -- valid rating
        JOIN video v ON vh.videoID = v.ID -- valid video
        JOIN hashtag h ON vh.hashtagID = h.ID -- valid hashtag
        WHERE LOWER(r.comment) LIKE '%thank you%' -- on condition
			  OR LOWER(r.comment) LIKE '%well done%'
        GROUP BY h.tag
	) AS counts
);

-- 8
-- TODO: limit to top 3 rather than just distinct top all
SELECT h.tag AS hashtag,
	   totalAnnotationsAsDestination,
	   totalDuration
FROM (
	SELECT hashtagID,
		   SUM(totalAnnotations) AS totalAnnotationsAsDestination,
		   SUM(totalDuration) AS totalDuration
	FROM (
		SELECT vh.hashtagID,
			   COUNT(a.destinationVideoID) AS totalAnnotations,
			   SUM(a.duration) AS totalDuration
		FROM video_hashtag vh
		JOIN annotation a ON vh.videoID = a.destinationVideoID
		GROUP BY vh.hashtagID, a.destinationVideoID
	) AS subquery
	GROUP BY hashtagID
) AS topHashtags
JOIN hashtag h ON topHashtags.hashtagID = h.id
ORDER BY totalAnnotationsAsDestination DESC;

-- 9
SELECT DISTINCT meme_creators.realName,
				meme_creators.screenName
                -- , meme_creators.tag, tech_creators.realName, tech_creators.screenName, tech_creators.tag
FROM (
	-- get meme creators
	SELECT DISTINCT cc.realName,
					cc.screenName,
					h.tag,
                    c.creatorID, 
                    c.videoID
    FROM content_creator cc
	JOIN content_creator_hashtag cch ON cc.ID = cch.creatorID -- valid content_creator hashtags
    JOIN hashtag h ON cch.hashtagID = h.ID -- valid hashtag
    JOIN cocreator c ON cc.ID = c.creatorID -- valid cocreated
	WHERE h.tag = '#memes' -- on condition
	GROUP BY cc.realName, 
			 cc.screenName, 
             h.tag, 
             c.creatorID, 
             c.videoID
) AS meme_creators
INNER JOIN (
	-- get tech creators
	SELECT DISTINCT cc.realName, 
					cc.screenName, 
                    h.tag, 
                    c.creatorID, 
                    c.videoID
    FROM content_creator cc
	JOIN content_creator_hashtag cch ON cc.ID = cch.creatorID -- valid content_creator hashtags
    JOIN hashtag h ON cch.hashtagID = h.ID -- valid hashtag
    JOIN cocreator c ON cc.ID = c.creatorID -- has cocreated
	WHERE h.tag = '#technology' -- on condition
	GROUP BY cc.realName, 
			 cc.screenName, 
             h.tag, 
             c.creatorID, 
             c.videoID
) AS tech_creators
-- where co-created same video and not same person
ON meme_creators.videoID = tech_creators.videoID
   AND meme_creators.creatorID != tech_creators.creatorID;

-- 10
SELECT DISTINCT cc.realName, 
				cc.screenName
FROM content_creator cc
JOIN (
	SELECT meme_creators.cocreatorID
	FROM (
		-- get all cocreated videos after datetime
		SELECT DISTINCT c1.creatorID AS ogcreatorID,
						c2.creatorID AS cocreatorID,
                        c2.videoID
                         -- ,v.uploaded, cc.realName, cc.screenName
		FROM cocreator c1
		JOIN content_creator cc ON c1.creatorID = cc.ID -- get 'INFO20003Memes'
								   AND cc.screenName = 'INFO20003Memes'
		INNER JOIN cocreator c2 ON c1.videoID = c2.videoID -- get all cocreators of 'INFO20003Memes' except self
							       AND c1.creatorID != c2.creatorID
		JOIN video v ON c1.videoID = v.ID  -- valid video
		WHERE v.uploaded > '2023-01-01 00:00:00' -- on condition
        GROUP BY ogcreatorID, 
				 cocreatorID, 
                 c2.videoID
	) AS meme_creators
	JOIN (
		-- get all cocreated videos before datetime
		SELECT DISTINCT c1.creatorID AS ogcreatorID, 
						c2.creatorID AS cocreatorID, 
                        c2.videoID
		FROM cocreator c1
		JOIN content_creator cc ON c1.creatorID = cc.ID  -- get 'INFO20003Memes'
								   AND cc.screenName = 'INFO20003Memes'
		INNER JOIN cocreator c2 ON c1.videoID = c2.videoID -- get all cocreators of 'INFO20003Memes' except self
								   AND c1.creatorID != c2.creatorID
		JOIN video v ON c1.videoID = v.ID
		WHERE v.uploaded < '2023-01-01 00:00:00' -- on condition
        GROUP BY ogcreatorID, 
				 cocreatorID, 
                 c2.videoID
	) AS tech_creators
    -- where cocreated after datetime and not cocreated before datetime
	WHERE meme_creators.cocreatorID != tech_creators.cocreatorID
		  AND meme_creators.videoID != tech_creators.videoID
) AS cocreators
WHERE cc.ID = cocreators.cocreatorID
