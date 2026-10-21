import RouteTemplate from "ember-route-template";
import GuestCtaDashboard from "../../../components/guest-cta/dashboard";

export default RouteTemplate(
  <template><GuestCtaDashboard @model={{@model}} @placement="reply" /></template>
);
