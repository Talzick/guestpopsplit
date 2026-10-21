# frozen_string_literal: true

module GuestCta
  # Shared by the admin controllers that create or edit variants: the plain
  # fields go through strong parameters; the reply's category overrides are a
  # JSON array the editor sends as one string, so an emptied list still
  # arrives (a form-encoded empty array would simply be absent).
  module VariantParams
    def variant_params(placement)
      permitted =
        params.require(:variant).permit(:name, *GuestCta::Variant.editable_fields_for(placement))
      if placement.to_s == "reply" && params[:variant].key?(:reply_category_overrides)
        permitted[:reply_category_overrides] =
          GuestCta::Variant.parse_overrides(params[:variant][:reply_category_overrides])
      end
      permitted
    end
  end
end
