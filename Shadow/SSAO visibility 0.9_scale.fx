#define SSAO_VISIBILITY_ENABLE 1
#define SSAO_RECIEVER_ALPHA_ENABLE 1
#define SSAO_RECIEVER_ALPHA_MAP_ENABLE 1

static const float visibility = 0.9; // SSAO visibility

// {{{ scale.fx
#define SCALING_ENABLED 1
// }}}

#include "../shader/SSAOVisibility.fxsub"