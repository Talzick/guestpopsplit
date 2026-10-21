import Component from "@glimmer/component";
import AdReply from "./ad-reply";
import PostBanner from "./post-banner";

// Everything the plugin places under the first post of a topic for logged-out
// visitors, in a fixed order: the guest reply directly under the post,
// then the banner. Each child checks its own switch and config.
export default class AfterFirstPost extends Component {
  static shouldRender(args, context) {
    const post = args.post || args.outletArgs?.post;
    return !!post && post.post_number === 1 && !context.currentUser;
  }

  get post() {
    return this.args.post || this.args.outletArgs?.post;
  }

  <template>
    <AdReply @post={{this.post}} />
    <PostBanner @post={{this.post}} />
  </template>
}
