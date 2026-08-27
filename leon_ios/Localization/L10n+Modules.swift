import Foundation

extension L10n {
    // MARK: - Shared actions

    enum Action {
        static let save = LocalizedStringResource("common.save", defaultValue: "保存")
        static let delete = LocalizedStringResource("common.delete", defaultValue: "删除")
        static let edit = LocalizedStringResource("common.edit", defaultValue: "编辑")
        static let done = LocalizedStringResource("common.done", defaultValue: "完成")
        static let manage = LocalizedStringResource("common.manage", defaultValue: "管理")
        static let search = LocalizedStringResource("common.search", defaultValue: "搜索")
        static let clear = LocalizedStringResource("common.clear", defaultValue: "清除")
        static let clearAll = LocalizedStringResource("common.clear_all", defaultValue: "清空")
        static let name = LocalizedStringResource("common.name", defaultValue: "名称")
        static let quantity = LocalizedStringResource("common.quantity", defaultValue: "数量")
        static let location = LocalizedStringResource("common.location", defaultValue: "位置")
        static let tags = LocalizedStringResource("common.tags", defaultValue: "标签")
        static let note = LocalizedStringResource("common.note", defaultValue: "备注")
        static let optional = LocalizedStringResource("common.optional", defaultValue: "可选")
        static let preview = LocalizedStringResource("common.preview", defaultValue: "预览")
        static let markUsed = LocalizedStringResource("common.mark_used", defaultValue: "用掉")
        static let unitPortion = LocalizedStringResource("common.unit_portion", defaultValue: "份")
        static let status = LocalizedStringResource("common.status", defaultValue: "状态")
        static let filter = LocalizedStringResource("common.filter", defaultValue: "筛选")
        static let add = LocalizedStringResource("common.add", defaultValue: "新增")
    }

    // MARK: - Ingredients

    enum Ingredients {
        static let listTitle = LocalizedStringResource("ingredients.list.title", defaultValue: "我的食材")
        static let searchPrompt = LocalizedStringResource(
            "ingredients.list.search_prompt",
            defaultValue: "搜索名称/标签/位置"
        )
        static let listSubtitle = LocalizedStringResource(
            "ingredients.list.subtitle",
            defaultValue: "按位置与到期状态快速浏览库存"
        )
        static let emptyTitle = LocalizedStringResource("ingredients.list.empty_title", defaultValue: "还没有食材")
        static let emptySubtitle = LocalizedStringResource(
            "ingredients.list.empty_subtitle",
            defaultValue: "先添加几个常用食材，后面就能直接带着食材去推荐。"
        )

        static let statusExpiring = LocalizedStringResource("ingredients.status.expiring", defaultValue: "临期")
        static let statusFresh = LocalizedStringResource("ingredients.status.fresh", defaultValue: "新鲜")
        static let statusNoExpiry = LocalizedStringResource("ingredients.status.no_expiry", defaultValue: "无到期日")
        static let statusExpired = LocalizedStringResource("ingredients.status.expired", defaultValue: "已过期")

        static let postpone1d = LocalizedStringResource("ingredients.action.postpone_1d", defaultValue: "延期 1 天")
        static let goRecommend = LocalizedStringResource("ingredients.action.go_recommend", defaultValue: "去推荐")
        static let discard = LocalizedStringResource("ingredients.action.discard", defaultValue: "丢弃")

        static let filterShowArchived = LocalizedStringResource(
            "ingredients.filter.show_archived",
            defaultValue: "显示已归档"
        )
        static let filterNoTags = LocalizedStringResource("ingredients.filter.no_tags", defaultValue: "暂无标签")
        static let filterClear = LocalizedStringResource("ingredients.filter.clear", defaultValue: "清除筛选")
        static let filterTitle = LocalizedStringResource("ingredients.filter.title", defaultValue: "筛选")

        static let editorTitleNew = LocalizedStringResource("ingredients.editor.title_new", defaultValue: "新增食材")
        static let editorTitleEdit = LocalizedStringResource("ingredients.editor.title_edit", defaultValue: "编辑食材")
        static let presetsHeader = LocalizedStringResource("ingredients.editor.presets_header", defaultValue: "常用")
        static let presetsFooter = LocalizedStringResource(
            "ingredients.editor.presets_footer",
            defaultValue: "点选预设可快速填充名称/单位/位置，并可带默认到期天数与标签。"
        )
        static let unitPrompt = LocalizedStringResource(
            "ingredients.editor.unit_prompt",
            defaultValue: "单位（如：个/份/kg）"
        )
        static let expirySection = LocalizedStringResource("ingredients.editor.expiry_section", defaultValue: "到期提醒")
        static let setExpiry = LocalizedStringResource("ingredients.editor.set_expiry", defaultValue: "设置到期日")
        static let expiryDate = LocalizedStringResource("ingredients.editor.expiry_date", defaultValue: "到期日")
        static let tagsPrompt = LocalizedStringResource(
            "ingredients.editor.tags_prompt",
            defaultValue: "用空格分隔（如：蔬菜 肉类）"
        )

        static let detailExpirySection = LocalizedStringResource("ingredients.detail.expiry_section", defaultValue: "到期")
        static let detailArchive = LocalizedStringResource(
            "ingredients.detail.archive",
            defaultValue: "标记为已用完（归档）"
        )
        static let detailNotFound = LocalizedStringResource("ingredients.detail.not_found", defaultValue: "找不到该食材")
        static let detailExpiryNone = LocalizedStringResource("ingredients.detail.expiry_none", defaultValue: "无")

        static func deleteConfirm(_ name: String) -> String {
            L10n.format("ingredients.detail.delete_confirm", name)
        }

        static let freshnessExpired = LocalizedStringResource("ingredients.freshness.expired", defaultValue: "已过期")
        static let freshnessExpiredShort = LocalizedStringResource(
            "ingredients.freshness.expired_short",
            defaultValue: "过期"
        )
        static let freshnessExpiresToday = LocalizedStringResource(
            "ingredients.freshness.expires_today",
            defaultValue: "今天到期"
        )
        static let freshnessFresh = LocalizedStringResource("ingredients.freshness.fresh", defaultValue: "新鲜")
        static let freshnessNoReminder = LocalizedStringResource(
            "ingredients.freshness.no_reminder",
            defaultValue: "不提醒"
        )

        static func freshnessDaysLeft(_ days: Int) -> String {
            L10n.format("ingredients.freshness.days_left", days)
        }

        static func freshnessExpiring(_ days: Int) -> String {
            L10n.format("ingredients.freshness.expiring_detail", days)
        }

        static let locationFridgeChill = LocalizedStringResource(
            "ingredients.location.fridge_chill",
            defaultValue: "冰箱·冷藏"
        )
        static let locationFridgeFreeze = LocalizedStringResource(
            "ingredients.location.fridge_freeze",
            defaultValue: "冰箱·冷冻"
        )
        static let locationPantry = LocalizedStringResource(
            "ingredients.location.pantry",
            defaultValue: "常温·储物柜"
        )
        static let locationOther = LocalizedStringResource("ingredients.location.other", defaultValue: "其他")

        static let fabAddA11y = LocalizedStringResource("ingredients.fab.add_a11y", defaultValue: "新增食材")
    }

    // MARK: - Recommend

    enum Recommend {
        static let homeTitle = LocalizedStringResource("recommend.home.title", defaultValue: "推荐")
        static let searchPrompt = LocalizedStringResource("recommend.search.prompt", defaultValue: "搜索菜谱")

        static let channelAll = LocalizedStringResource("recommend.channel.all", defaultValue: "全部")
        static let channelQuick = LocalizedStringResource("recommend.channel.quick", defaultValue: "快手")
        static let channelHome = LocalizedStringResource("recommend.channel.home", defaultValue: "家常")
        static let channelStock = LocalizedStringResource("recommend.channel.stock", defaultValue: "清库存")
        static let channelSection = LocalizedStringResource("recommend.channel.section", defaultValue: "发现频道")
        static let channelSubtitleAll = LocalizedStringResource(
            "recommend.channel.subtitle_all",
            defaultValue: "按灵感浏览"
        )
        static let channelSubtitleQuick = LocalizedStringResource(
            "recommend.channel.subtitle_quick",
            defaultValue: "更适合今天快做"
        )
        static let channelSubtitleHome = LocalizedStringResource(
            "recommend.channel.subtitle_home",
            defaultValue: "偏家常稳妥路线"
        )
        static let channelSubtitleStock = LocalizedStringResource(
            "recommend.channel.subtitle_stock",
            defaultValue: "优先考虑消耗现有食材"
        )

        static let contextTitle = LocalizedStringResource("recommend.context.title", defaultValue: "当前食材上下文")

        static func contextBroughtIn(_ count: Int, _ names: String) -> String {
            L10n.format("recommend.context.brought_in", count, names)
        }

        static let heroTitle = LocalizedStringResource("recommend.hero.title", defaultValue: "今天吃点什么")
        static let heroSubtitleDefault = LocalizedStringResource(
            "recommend.hero.subtitle_default",
            defaultValue: "按你当前的收藏偏好、家常灵感和热门菜谱，整理成更适合快速浏览的发现流。"
        )
        static let heroSubtitleWithIngredients = LocalizedStringResource(
            "recommend.hero.subtitle_with_ingredients",
            defaultValue: "已经把你勾选的食材带进来了，先从更接近可开做的方向帮你铺开。"
        )
        static func heroSubtitleFlavors(_ flavors: String) -> String {
            L10n.format("recommend.hero.subtitle_flavors", flavors)
        }
        static let dailyBadge = LocalizedStringResource("recommend.daily.badge", defaultValue: "今日推荐")
        static let heroMetricToday = LocalizedStringResource("recommend.hero.metric_today", defaultValue: "今日推荐")
        static let heroMetricHot = LocalizedStringResource("recommend.hero.metric_hot", defaultValue: "热门词")
        static let heroMetricRecent = LocalizedStringResource("recommend.hero.metric_recent", defaultValue: "最近搜索")

        static let feedTitle = LocalizedStringResource("recommend.feed.title", defaultValue: "发现菜谱")
        static let feedTitleByIngredients = LocalizedStringResource(
            "recommend.feed.title_by_ingredients",
            defaultValue: "按食材推荐"
        )
        static let filterStock = LocalizedStringResource("recommend.filter.stock", defaultValue: "清库存")
        static let filterStockEmpty = LocalizedStringResource(
            "recommend.filter.stock_empty",
            defaultValue: "先在食材页添加食材，再来清库存"
        )
        static let feedLoading = LocalizedStringResource("recommend.feed.loading", defaultValue: "正在准备推荐")
        static let feedEmptyTitle = LocalizedStringResource("recommend.feed.empty_title", defaultValue: "还没有推荐结果")
        static let feedEmptySubtitle = LocalizedStringResource(
            "recommend.feed.empty_subtitle",
            defaultValue: "可以先从食材页带入几个食材，或者直接搜索菜谱。"
        )

        static let searchRecent = LocalizedStringResource("recommend.search.recent", defaultValue: "最近搜索")
        static let searchHot = LocalizedStringResource("recommend.search.hot", defaultValue: "热门搜索")
        static let searchSuggestionsTitle = LocalizedStringResource(
            "recommend.search.suggestions_title",
            defaultValue: "搜索建议"
        )
        static let searchSuggestionsLoading = LocalizedStringResource(
            "recommend.search.suggestions_loading",
            defaultValue: "正在整理建议"
        )
        static let searchSuggestionsEmptyTitle = LocalizedStringResource(
            "recommend.search.suggestions_empty_title",
            defaultValue: "还没有合适的建议词"
        )
        static let searchSuggestionsEmptySubtitle = LocalizedStringResource(
            "recommend.search.suggestions_empty_subtitle",
            defaultValue: "可以直接点右上角搜索，也可以换个关键词试试。"
        )
        static let searchResultsTitle = LocalizedStringResource(
            "recommend.search.results_title",
            defaultValue: "搜索结果"
        )
        static let searchRetry = LocalizedStringResource("recommend.search.retry", defaultValue: "重新搜索")
        static let searchLoading = LocalizedStringResource("recommend.search.loading", defaultValue: "正在搜索菜谱")
        static let searchEmptyTitle = LocalizedStringResource(
            "recommend.search.empty_title",
            defaultValue: "没有找到结果"
        )
        static let searchEmptySubtitle = LocalizedStringResource(
            "recommend.search.empty_subtitle",
            defaultValue: "换个关键词试试，或者先点搜索建议继续找。"
        )

        static func searchSuggestionsHint(_ query: String) -> String {
            L10n.format("recommend.search.suggestions_hint", query)
        }

        static func searchKeyword(_ query: String) -> String {
            L10n.format("recommend.search.keyword", query)
        }

        static func searchResultCount(_ count: Int) -> String {
            L10n.format("recommend.search.result_count", count)
        }

        static let cardReasonPlaceholder = LocalizedStringResource(
            "recommend.card.reason_placeholder",
            defaultValue: "等待真实推荐理由"
        )
        static let cardBadgeFavorited = LocalizedStringResource("recommend.card.badge_favorited", defaultValue: "已收藏")
        static let cardBadgeHighMatch = LocalizedStringResource("recommend.card.badge_high_match", defaultValue: "高匹配")
        static let cardBadgeHome = LocalizedStringResource("recommend.card.badge_home", defaultValue: "家常推荐")
        static let cardTagQuick = LocalizedStringResource("recommend.card.tag_quick", defaultValue: "快做")
        static let cardTagHome = LocalizedStringResource("recommend.card.tag_home", defaultValue: "家常")
        static let cardTagIngredient = LocalizedStringResource("recommend.card.tag_ingredient", defaultValue: "食材向")
        static let cardTagInspiration = LocalizedStringResource(
            "recommend.card.tag_inspiration",
            defaultValue: "灵感菜谱"
        )
        static let cardTagTonight = LocalizedStringResource("recommend.card.tag_tonight", defaultValue: "今晚可做")
        static let cardChannelPriority = LocalizedStringResource(
            "recommend.card.channel_priority",
            defaultValue: "优先匹配"
        )
        static let cardChannelFavorite = LocalizedStringResource(
            "recommend.card.channel_favorite",
            defaultValue: "收藏偏好"
        )
        static let cardChannelDiscover = LocalizedStringResource(
            "recommend.card.channel_discover",
            defaultValue: "发现流"
        )

        static func cardHeat(_ value: Int) -> String {
            L10n.format("recommend.card.heat", value)
        }

        static let authorKitchen = LocalizedStringResource("recommend.card.author_kitchen", defaultValue: "Leon 厨房")
        static let authorDinner = LocalizedStringResource("recommend.card.author_dinner", defaultValue: "晚餐灵感")
        static let authorStock = LocalizedStringResource("recommend.card.author_stock", defaultValue: "清库存研究所")
        static let authorToday = LocalizedStringResource("recommend.card.author_today", defaultValue: "今日下饭局")

        static let detailLoading = LocalizedStringResource("recommend.detail.loading", defaultValue: "正在加载食谱详情")
        static let detailReasonFallback = LocalizedStringResource(
            "recommend.detail.reason_fallback",
            defaultValue: "适合当前阶段作为 1.0 的食谱详情承接。"
        )
        static let detailActionsSection = LocalizedStringResource(
            "recommend.detail.actions_section",
            defaultValue: "操作入口"
        )
        static let detailLike = LocalizedStringResource("recommend.detail.like", defaultValue: "点赞")
        static let detailFavorite = LocalizedStringResource("recommend.detail.favorite", defaultValue: "收藏")
        static let detailSyncHintAuthed = LocalizedStringResource(
            "recommend.detail.sync_hint_authed",
            defaultValue: "点赞、收藏和浏览历史会同步沉淀到“我的”。"
        )
        static let detailSyncHintGuest = LocalizedStringResource(
            "recommend.detail.sync_hint_guest",
            defaultValue: "登录后可以把点赞、收藏、历史同步到“我的”。"
        )
        static let detailIngredients = LocalizedStringResource("recommend.detail.ingredients", defaultValue: "食材")
        static let detailSteps = LocalizedStringResource("recommend.detail.steps", defaultValue: "步骤")
        static let detailServiceStatus = LocalizedStringResource(
            "recommend.detail.service_status",
            defaultValue: "服务状态"
        )
        static let detailUnavailableTitle = LocalizedStringResource(
            "recommend.detail.unavailable_title",
            defaultValue: "暂时拿不到详情"
        )
        static let detailUnavailableSubtitle = LocalizedStringResource(
            "recommend.detail.unavailable_subtitle",
            defaultValue: "可以稍后重试，或者先继续浏览推荐列表。"
        )
        static let detailTitle = LocalizedStringResource("recommend.detail.title", defaultValue: "食谱详情")

        static func detailStep(_ number: Int) -> String {
            L10n.format("recommend.detail.step_n", number)
        }

        static let fallbackIngredientMain = LocalizedStringResource(
            "recommend.detail.fallback_ingredient_main",
            defaultValue: "主食材待补齐"
        )
        static let fallbackIngredientSide = LocalizedStringResource(
            "recommend.detail.fallback_ingredient_side",
            defaultValue: "辅料待补齐"
        )
        static let fallbackIngredientSeasoning = LocalizedStringResource(
            "recommend.detail.fallback_ingredient_seasoning",
            defaultValue: "调味待补齐"
        )
        static let fallbackStep1 = LocalizedStringResource(
            "recommend.detail.fallback_step_1",
            defaultValue: "先根据当前推荐结果准备食材。"
        )
        static let fallbackStep2 = LocalizedStringResource(
            "recommend.detail.fallback_step_2",
            defaultValue: "按家常做法完成预处理与下锅。"
        )
        static let fallbackStep3 = LocalizedStringResource(
            "recommend.detail.fallback_step_3",
            defaultValue: "等后端详情接口进一步补全更完整的步骤。"
        )

        static func detailIngredientsCount(_ count: Int) -> String {
            L10n.format("recommend.detail.ingredients_count", count)
        }

        static let galleryTapHint = LocalizedStringResource(
            "recommend.gallery.tap_hint",
            defaultValue: "点击查看大图"
        )
        static let galleryEmptyTitle = LocalizedStringResource(
            "recommend.gallery.empty_title",
            defaultValue: "暂无图片"
        )
        static let galleryEmptySubtitle = LocalizedStringResource(
            "recommend.gallery.empty_subtitle",
            defaultValue: "这道菜谱还没有可展示的图片。"
        )
    }

    // MARK: - Reminders

    enum Reminders {
        static let title = LocalizedStringResource("reminders.title", defaultValue: "提醒")
        static let emptyTitle = LocalizedStringResource("reminders.empty_title", defaultValue: "暂无提醒")
        static let emptySubtitle = LocalizedStringResource(
            "reminders.empty_subtitle",
            defaultValue: "设置到期日后，这里会自动聚合临期与过期食材。"
        )
        static let footer = LocalizedStringResource(
            "reminders.footer",
            defaultValue: "临期与过期食材会在这里集中展示，方便你优先处理。"
        )
        static let summaryHint = LocalizedStringResource(
            "reminders.summary_hint",
            defaultValue: "优先处理临期食材，避免浪费。"
        )

        static func summaryCount(_ count: Int) -> String {
            L10n.format("reminders.summary_count", count)
        }

        static func chipExpiring(_ count: Int) -> String {
            L10n.format("reminders.chip_expiring", count)
        }

        static func chipExpired(_ count: Int) -> String {
            L10n.format("reminders.chip_expired", count)
        }
    }

    // MARK: - Presets

    enum Presets {
        static let managerTitle = LocalizedStringResource("presets.manager.title", defaultValue: "管理预设")
        static let managerAddA11y = LocalizedStringResource("presets.manager.add_a11y", defaultValue: "新增预设")
        static let editorTitleNew = LocalizedStringResource("presets.editor.title_new", defaultValue: "新增预设")
        static let editorTitleEdit = LocalizedStringResource("presets.editor.title_edit", defaultValue: "编辑预设")
        static let unitPrompt = LocalizedStringResource(
            "presets.editor.unit_prompt",
            defaultValue: "默认单位（如：个/枚/kg）"
        )
        static let defaultLocation = LocalizedStringResource(
            "presets.editor.default_location",
            defaultValue: "默认位置"
        )
        static let iconSection = LocalizedStringResource("presets.editor.icon_section", defaultValue: "图标")
        static let iconType = LocalizedStringResource("presets.editor.icon_type", defaultValue: "类型")
        static let iconSystem = LocalizedStringResource("presets.editor.icon_system", defaultValue: "系统图标")
        static let iconAsset = LocalizedStringResource("presets.editor.icon_asset", defaultValue: "图片资源")
        static let sfSymbol = LocalizedStringResource("presets.editor.sf_symbol", defaultValue: "SF Symbol 名称")
        static let assetName = LocalizedStringResource("presets.editor.asset_name", defaultValue: "Assets 名称")
        static let expirySection = LocalizedStringResource("presets.editor.expiry_section", defaultValue: "到期模板")
        static let useExpiryDays = LocalizedStringResource(
            "presets.editor.use_expiry_days",
            defaultValue: "使用默认到期天数"
        )
        static let defaultTags = LocalizedStringResource("presets.editor.default_tags", defaultValue: "默认标签")

        static func defaultDays(_ days: Int) -> String {
            L10n.format("presets.editor.default_days", days)
        }
    }

    // MARK: - OCR

    enum OCR {
        static let entryManual = LocalizedStringResource("ocr.entry.manual", defaultValue: "手动录入")
        static let entryReceipt = LocalizedStringResource("ocr.entry.receipt", defaultValue: "小票识别")
        static let title = LocalizedStringResource("ocr.import.title", defaultValue: "小票识别")
        static let pickPhoto = LocalizedStringResource("ocr.import.pick_photo", defaultValue: "选择小票图片")
        static let changePhoto = LocalizedStringResource("ocr.import.change_photo", defaultValue: "更换图片")
        static let startRecognize = LocalizedStringResource("ocr.import.start", defaultValue: "开始识别")
        static let recognizing = LocalizedStringResource("ocr.import.recognizing", defaultValue: "正在识别小票")
        static let candidatesTitle = LocalizedStringResource("ocr.import.candidates_title", defaultValue: "识别结果")
        static let selectAll = LocalizedStringResource("ocr.import.select_all", defaultValue: "全选")
        static let deselectAll = LocalizedStringResource("ocr.import.deselect_all", defaultValue: "取消全选")
        static let addSelected = LocalizedStringResource("ocr.import.add_selected", defaultValue: "加入食材")
        static let emptyCandidatesTitle = LocalizedStringResource(
            "ocr.import.empty_candidates_title",
            defaultValue: "没有识别到食材"
        )
        static let emptyCandidatesSubtitle = LocalizedStringResource(
            "ocr.import.empty_candidates_subtitle",
            defaultValue: "可以换一张更清晰的小票图片再试。"
        )
        static let pickHint = LocalizedStringResource(
            "ocr.import.pick_hint",
            defaultValue: "从相册选择一张小票照片，识别后勾选要加入的食材。"
        )
        static let importNote = LocalizedStringResource("ocr.import.note", defaultValue: "小票导入")
        static let summaryTitle = LocalizedStringResource("ocr.import.summary_title", defaultValue: "小票信息")
        static let copyResponse = LocalizedStringResource("ocr.import.copy_response", defaultValue: "复制接口返回")
        static let copyResponseDone = LocalizedStringResource("ocr.import.copy_response_done", defaultValue: "已复制到剪贴板")
        static let debugSection = LocalizedStringResource("ocr.import.debug_section", defaultValue: "调试")

        static func selectedCount(_ count: Int) -> String {
            L10n.format("ocr.import.selected_count", count)
        }

        static func quantityLabel(_ quantity: Double) -> String {
            let isInt = abs(quantity.rounded() - quantity) < 0.000_001
            let numberText = isInt ? String(Int(quantity)) : String(format: "%.1f", quantity)
            return L10n.format("ocr.import.quantity_label", numberText)
        }

        static func priceLabel(_ price: Double) -> String {
            L10n.format("ocr.import.price_label", String(format: "%.2f", price))
        }

        static func summaryPlatform(_ platform: String) -> String {
            L10n.format("ocr.import.summary_platform", platform)
        }

        static func summaryOrderStatus(_ status: String) -> String {
            L10n.format("ocr.import.summary_order_status", status)
        }

        static func summaryTotal(_ amount: Double) -> String {
            L10n.format("ocr.import.summary_total", String(format: "%.2f", amount))
        }
    }

    // MARK: - Explore

    enum Explore {
        static let like = LocalizedStringResource("explore.action.like", defaultValue: "赞")
        static let comment = LocalizedStringResource("explore.action.comment", defaultValue: "评论")
        static let share = LocalizedStringResource("explore.action.share", defaultValue: "分享")
        static let pauseHint = LocalizedStringResource("explore.pause_hint", defaultValue: "轻点暂停")
    }
}
