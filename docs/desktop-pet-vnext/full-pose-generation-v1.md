# 专注与休息完整姿态素材 v1

2026-10-09。内置 ImageGen；transparent_background=true。母稿负责角色身份，第一版专注/休息原稿仅负责动作关系。实际输出均为 1536×1024 RGBA、3 列 × 2 行、每格512，6帧。生成原文件保留，选定产物复制进 assets。

专注素材：assets/tomy-seated-work-v1.png；休息素材：assets/tomy-seated-rest-v1.png。浏览器完整绘制每一帧，未把道具拼到旧站立身体上。assets/tomy-seated-motion-v1.json 记录每帧时长、统一取景边界与位置校准；位置校准按叶冠上缘与右缘抵消生成网格的平移差异，所有帧不独立缩放。

动作：专注坐着操作腿上的小电脑，左右手交替抬起/按键并眨眼；休息坐着双手捧杯，举杯喝一口，再放回。无桌椅、头牌、倒计时常驻。素材风格保持选定番茄的红绿配色、圆润体形、叶冠方向和左上光照。为独立样片，尚未接入 macOS 运行代码，也未获用户视觉验收。

动画导出：assets/tomy-seated-work-preview-v1.gif 与 assets/tomy-seated-rest-preview-v1.gif，96×96，由各6个姿态帧按实际播放顺序复用，取自实际预览页面六次逐帧截图的角色区域，只作格式编码与调色板导出。专注约5.95秒一轮，先重复打字动作再眨眼；休息约4.18秒一轮，放杯时复用上举的中间帧反向衔接。背景颜色来自预览卡片，原始精灵表仍保留透明alpha。

## 专注实际提示词

Use case: identity-preserving pixel-art character animation.
Create ONE production SPRITE ATLAS containing a coherent 6-frame TYPING LOOP for Tomy, on actual transparent alpha. Exactly 3 columns x 2 rows of equal 512x512 cells, 1536x1024 total, no gaps or grid marks. Read frames left to right, top row then bottom row.
Image 1 is the APPROVED CHARACTER IDENTITY: the rounded coral-red tomato, five asymmetrical green leaves with a tall leaf pointing upper-right, black oval eyes, peach cheeks, small curved smile, short red arms and feet, soft dimensional pixel shading lit upper-left. Preserve that identity, crown silhouette, body width, palette and light direction in every frame. Image 2 is ONLY a reference for meaningful laptop/hand interaction, NOT its old character design or its furniture.
Repose the APPROVED character into a clear SEATED WORKING pose: rounded body sitting low, both short feet resting forward at the floor baseline, both red arms reaching forwards with tiny hands touching actual keys. One small teal laptop rests directly on its lap, angled slightly left: screen on left, a visible short keyboard deck extending right under its hands. Head/eyes above laptop, entire face and crown unobstructed. The laptop is integrated into the action, not pasted on a standing torso. No table, headphones, chair, books, background or interface. Compact charming composition.
All six cells show the SAME seated character, same body/crown position and SAME stationary laptop, orthographic consistent camera. Each full figure fits x70..442 and y70..455 in its local 512px cell, ground baseline y455. Do not scale or recenter between frames. Keep crisp stepped pixel edges and pixel clusters, with the warm soft volume of image 1; not clay, vector, blurry painting or 3D render.
Frame 1: both hands on keyboard, open focused eyes looking slightly toward keys.
Frame 2: left forearm bends so left hand lifts a little above its keys, right hand presses down.
Frame 3: left hand presses its keys, right forearm bends and right hand lifts; the actual arm contours change.
Frame 4: both hands return to keyboard, eyes half close for a blink.
Frame 5: same working posture, eyes briefly closed into curved eyelids, right hand lightly presses keys.
Frame 6: eyes open again, hands back to frame 1 positions, ready for a seamless return to frame 1.
Visible alternating hand/forearm movement, approximately 8-14 source pixels, with meaningful contact and occlusion at the keyboard. Keep body, crown, laptop, camera and shading completely stable so it animates without jitter. Only fingers/forearms and eyelids move. EXACTLY one complete character per cell, no stray hands, duplicate limbs or floating props. Real transparency outside sprites; no drawn checkerboard, labels, numbers, borders, watermark, floor shadow or separate decorative elements.

## 休息实际提示词

Use case: identity-preserving pixel-art character animation.
Create ONE coherent 6-frame SIPPING TEA LOOP sprite atlas for the SAME Tomy. Output actual transparent RGBA, exactly 3 columns x 2 rows of equal 512x512 cells, canvas 1536x1024, left-to-right then top-to-bottom.
Image 1 is the approved tomato identity. Image 2 is the new approved-style seated typing sprite atlas: MATCH its exact rounded tomato, five asymmetrical green leaves with tall upper-right-pointing leaf, face spacing, coral palette, dark-red volume shadows, pixel cluster size and upper-left lighting. Image 3 only illustrates the old rest action (sitting and genuinely holding a cup); do not copy its old tomato design or backdrop.
Change the action to relaxed REST: Tomy sits down with two little feet extended forward, no laptop or furniture. A small warm cream/gold mug with a dark tea surface is genuinely held between TWO red hands. Hands wrap around the mug's sides; forearms change their angle as the mug rises. Keep the face above the mug visible until it reaches the mouth to sip. Express cozy relaxation through curved sleepy eyelids, a satisfied small smile and relaxed seated posture. No standing silhouette with a floating cup.
Lock the character's body size, crown, camera and foot baseline across the six frames. Whole sprite comfortably fits x70..442 and y70..455 within each cell, feet on y455. Crown highest point at y70. Same body and leaf pixel clusters each time. Preserve the same upper-left highlight from image 1 and image 2. The body is round, never pear-shaped or squashed.
Frame 1: open eyes, smiling, both hands hold mug low at lap.
Frame 2: BOTH forearms bend to lift mug halfway toward mouth, half-closed relaxed eyes.
Frame 3: mug touches mouth for a sip, both hands grip sides, eyes softly closed. Mug partly hides the lower smile naturally, NOT the eyes.
Frame 4: hold the same sipping pose, tiny cream steam curl above mug, eyes softly closed.
Frame 5: lower mug halfway back toward lap, eyes gently open and satisfied smile returns.
Frame 6: mug back at lap with both hands holding it, same pose as frame 1, one very small steam curl.
Meaningful upward/downward cup travel about 35-45 source pixels, accompanied by changing connected arm contours and natural overlap. Keep crown, head shape, seated feet and shading fixed so the loop has no zooming, mirroring or jitter. Exactly one full character per cell; no duplicate mugs, disconnected hands or extra fingers.
Crisp dimensional PIXEL ART matching the attached new typing atlas, no smooth vector, clay or photoreal 3D. NO background, floor, pillow, headphones, chair, desk, props apart from the single mug and tiny steam curl. No rendered checkerboard, text, labels, frame numbers, border, watermark or background shadow. True transparent alpha outside each sprite.
